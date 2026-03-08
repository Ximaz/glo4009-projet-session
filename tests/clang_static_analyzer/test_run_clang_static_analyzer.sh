#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/../.." && pwd)"
SCRIPT_UNDER_TEST="${PROJECT_ROOT}/clang_static_analyzer/run_clang_static_analyzer.sh"
TMP_ROOT="$(mktemp -d)"
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
    rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

pass() {
    echo "[PASS] $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo "[FAIL] $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    if [[ "${haystack}" == *"${needle}"* ]]; then
        pass "${test_name}"
    else
        echo "Expected to find: ${needle}"
        echo "Got:"
        echo "${haystack}"
        fail "${test_name}"
    fi
}

assert_exit_code() {
    local actual="$1"
    local expected="$2"
    local test_name="$3"

    if [[ "${actual}" -eq "${expected}" ]]; then
        pass "${test_name}"
    else
        echo "Expected exit code: ${expected}"
        echo "Actual exit code:   ${actual}"
        fail "${test_name}"
    fi
}

make_mock_clang() {
    local dir="$1"
    local mode="$2"

    mkdir -p "${dir}"

    cat > "${dir}/clang" <<MOCK
#!/usr/bin/env bash
set -eu

mode="${mode}"

case "\$mode" in
    warning)
        cat >&2 <<'EOT'
sample.c:10:5: warning: Potential leak of memory pointed to by 'ptr'
sample.c:10:5: note: Value stored to 'ptr' during its initialization is never released
EOT
        exit 0
        ;;
    two_warnings)
        cat >&2 <<'EOT'
sample.c:10:5: warning: Potential leak of memory pointed to by 'ptr'
sample.c:10:5: note: Value stored to 'ptr' during its initialization is never released
sample.c:20:3: warning: Dereference of null pointer
sample.c:20:3: note: Null pointer value stored to 'p'
EOT
        exit 0
        ;;
    clean)
        exit 0
        ;;
    failure)
        echo "clang: error: unknown argument: '--badflag'" >&2
        exit 1
        ;;
    *)
        echo "unknown mock mode" >&2
        exit 2
        ;;
esac
MOCK

    chmod +x "${dir}/clang"
}

run_test_missing_source_files() {
    local workdir="${TMP_ROOT}/test_missing_source"
    mkdir -p "${workdir}"

    set +e
    local output
    output="$(
        cd "${workdir}" && \
        env -i PATH="${PATH}" bash "${SCRIPT_UNDER_TEST}" 2>&1
    )"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 1 "missing source_files returns exit code 1"
    assert_contains "${output}" "source_files input is required" "missing source_files prints helpful message"
}

run_test_warning_is_reported() {
    local workdir="${TMP_ROOT}/test_warning"
    local mockdir="${workdir}/mockbin"
    mkdir -p "${workdir}"
    make_mock_clang "${mockdir}" warning

    cat > "${workdir}/sample.c" <<'SRC'
int main(void) { return 0; }
SRC

    set +e
    local output
    output="$(
        cd "${workdir}" && \
        env -i \
            PATH="${mockdir}:/usr/bin:/bin:/usr/local/bin" \
            INPUT_SOURCE_FILES="sample.c" \
            INPUT_TREAT_ERROR_AS_WARNING="false" \
            bash "${SCRIPT_UNDER_TEST}" 2>&1
    )"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 1 "warning produces non-zero exit when treated as error"
    assert_contains "${output}" "Clang Static Analyzer Report (1)" "warning creates first report"
    assert_contains "${output}" "Potential leak of memory pointed to by 'ptr'" "warning message is present"
}

run_test_warning_can_be_downgraded() {
    local workdir="${TMP_ROOT}/test_warning_as_warning"
    local mockdir="${workdir}/mockbin"
    mkdir -p "${workdir}"
    make_mock_clang "${mockdir}" warning

    cat > "${workdir}/sample.c" <<'SRC'
int main(void) { return 0; }
SRC

    set +e
    local output
    output="$(
        cd "${workdir}" && \
        env -i \
            PATH="${mockdir}:/usr/bin:/bin:/usr/local/bin" \
            INPUT_SOURCE_FILES="sample.c" \
            INPUT_TREAT_ERROR_AS_WARNING="true" \
            bash "${SCRIPT_UNDER_TEST}" 2>&1
    )"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 0 "warning mode exits with 0"
    assert_contains "${output}" "::warning file=sample.c,line=10,col=5" "warning mode emits warning annotation"
}

run_test_multiple_reports() {
    local workdir="${TMP_ROOT}/test_multiple_reports"
    local mockdir="${workdir}/mockbin"
    mkdir -p "${workdir}"
    make_mock_clang "${mockdir}" two_warnings

    cat > "${workdir}/sample.c" <<'SRC'
int main(void) { return 0; }
SRC

    set +e
    local output
    output="$(
        cd "${workdir}" && \
        env -i \
            PATH="${mockdir}:/usr/bin:/bin:/usr/local/bin" \
            INPUT_SOURCE_FILES="sample.c" \
            INPUT_TREAT_ERROR_AS_WARNING="false" \
            bash "${SCRIPT_UNDER_TEST}" 2>&1
    )"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 1 "multiple reports still return non-zero"
    assert_contains "${output}" "Clang Static Analyzer Report (1)" "first report is present"
    assert_contains "${output}" "Clang Static Analyzer Report (2)" "second report is present"
}

run_test_hard_failure_is_propagated() {
    local workdir="${TMP_ROOT}/test_failure"
    local mockdir="${workdir}/mockbin"
    mkdir -p "${workdir}"
    make_mock_clang "${mockdir}" failure

    cat > "${workdir}/sample.c" <<'SRC'
int main(void) { return 0; }
SRC

    set +e
    local output
    output="$(
        cd "${workdir}" && \
        env -i \
            PATH="${mockdir}:/usr/bin:/bin:/usr/local/bin" \
            INPUT_SOURCE_FILES="sample.c" \
            INPUT_TREAT_ERROR_AS_WARNING="false" \
            bash "${SCRIPT_UNDER_TEST}" 2>&1
    )"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 1 "clang invocation failure is propagated"
    assert_contains "${output}" "clang static analyzer failed to run" "hard failure prints explicit error"
}

main() {
    run_test_missing_source_files
    run_test_warning_is_reported
    run_test_warning_can_be_downgraded
    run_test_multiple_reports
    run_test_hard_failure_is_propagated

    echo
    echo "=========================="
    echo "Tests passed: ${TESTS_PASSED}"
    echo "Tests failed: ${TESTS_FAILED}"
    echo "=========================="

    if [[ "${TESTS_FAILED}" -ne 0 ]]; then
        exit 1
    fi
}

main
