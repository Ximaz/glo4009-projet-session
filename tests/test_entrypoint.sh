#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"
SCRIPT_UNDER_TEST="${PROJECT_ROOT}/entrypoint.bash"
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

# Creates a fake dispatcher target (valgrind.bash or clang_static_analyzer.bash)
# that simply prints its name and exits 0.
make_mock_target() {
    local dir="$1"
    local name="$2"

    mkdir -p "${dir}"
    cat > "${dir}/${name}" <<MOCK
#!/usr/bin/env bash
echo "called:${name}"
exit 0
MOCK
    chmod +x "${dir}/${name}"
}

# Runs entrypoint.bash with a fake /root directory substituted via PATH tricks.
# We patch /root references by wrapping the entrypoint in a subshell that
# overrides the paths via symlinks in a temp dir.
run_entrypoint() {
    local mode="$1"
    local root_dir="$2"

    # Patch the script so /root/ points to our fake root dir
    local patched="${TMP_ROOT}/entrypoint_patched_${mode}.bash"
    sed "s|/root/|${root_dir}/|g" "${SCRIPT_UNDER_TEST}" > "${patched}"
    chmod +x "${patched}"

    set +e
    local output
    output="$(env -i INPUT_MODE="${mode}" bash "${patched}" 2>&1)"
    local exit_code=$?
    set -e

    echo "${output}"
    return "${exit_code}"
}

run_test_valgrind_mode() {
    local root_dir="${TMP_ROOT}/root_valgrind"
    make_mock_target "${root_dir}" "valgrind.bash"
    make_mock_target "${root_dir}" "clang_static_analyzer.bash"

    set +e
    local output
    output="$(run_entrypoint "valgrind" "${root_dir}" 2>&1)"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 0 "valgrind mode exits 0"
    assert_contains "${output}" "called:valgrind.bash" "valgrind mode dispatches to valgrind.bash"
}

run_test_clang_static_analyzer_mode() {
    local root_dir="${TMP_ROOT}/root_clang"
    make_mock_target "${root_dir}" "valgrind.bash"
    make_mock_target "${root_dir}" "clang_static_analyzer.bash"

    set +e
    local output
    output="$(run_entrypoint "clang-static-analyzer" "${root_dir}" 2>&1)"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 0 "clang-static-analyzer mode exits 0"
    assert_contains "${output}" "called:clang_static_analyzer.bash" "clang-static-analyzer mode dispatches to clang_static_analyzer.bash"
}

run_test_default_mode_is_valgrind() {
    local root_dir="${TMP_ROOT}/root_default"
    make_mock_target "${root_dir}" "valgrind.bash"
    make_mock_target "${root_dir}" "clang_static_analyzer.bash"

    local patched="${TMP_ROOT}/entrypoint_patched_default.bash"
    sed "s|/root/|${root_dir}/|g" "${SCRIPT_UNDER_TEST}" > "${patched}"
    chmod +x "${patched}"

    set +e
    local output
    # Run without INPUT_MODE set
    output="$(env -i bash "${patched}" 2>&1)"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 0 "default mode exits 0"
    assert_contains "${output}" "called:valgrind.bash" "default mode dispatches to valgrind.bash"
}

run_test_unknown_mode() {
    local root_dir="${TMP_ROOT}/root_unknown"
    make_mock_target "${root_dir}" "valgrind.bash"
    make_mock_target "${root_dir}" "clang_static_analyzer.bash"

    set +e
    local output
    output="$(run_entrypoint "unknown-tool" "${root_dir}" 2>&1)"
    local exit_code=$?
    set -e

    assert_exit_code "${exit_code}" 1 "unknown mode exits 1"
    assert_contains "${output}" "Unknown mode" "unknown mode prints error message"
}

main() {
    run_test_valgrind_mode
    run_test_clang_static_analyzer_mode
    run_test_default_mode_is_valgrind
    run_test_unknown_mode

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