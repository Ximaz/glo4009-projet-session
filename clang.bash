#!/usr/bin/env bash
set -xeu

get_sanitizer_flags() {
    local sanitizer="${1}"
    case "${sanitizer}" in
        asan)
            echo "-fsanitize=address -fno-omit-frame-pointer"
            ;;
        ubsan)
            echo "-fsanitize=undefined"
            ;;
        tsan)
            echo "-fsanitize=thread"
            ;;
        msan)
            echo "-fsanitize=memory -fno-omit-frame-pointer"
            ;;
        lsan)
            echo "-fsanitize=leak"
            ;;
        *)
            echo "::error::Unknown sanitizer '${sanitizer}'. Must be one of: asan, ubsan, tsan, msan, lsan."
            exit 1
            ;;
    esac
}

parse_sanitizer_output() {
    local output_file="${1}"
    local kind="error"
    local status=0
    local report_id=1

    if [[ "${INPUT_TREAT_ERROR_AS_WARNING}" == "true" ]]; then
        kind="warning"
    fi

    declare -a SANITIZER_PATTERNS=(
        "ERROR: AddressSanitizer"
        "ERROR: LeakSanitizer"
        "WARNING: ThreadSanitizer"
        "WARNING: MemorySanitizer"
        "runtime error:"
    )

    local current_error=""
    local in_error=0

    while IFS= read -r line; do
        local matched=0
        for pattern in "${SANITIZER_PATTERNS[@]}"; do
            if [[ "${line}" == *"${pattern}"* ]]; then
                if [[ "${in_error}" -eq 1 && "${current_error}" != "" ]]; then
                    echo "::${kind} title=Clang Sanitizer Report (${report_id})::${current_error}"
                    report_id=$(( report_id + 1 ))
                    status=1
                fi
                current_error="${line}"
                in_error=1
                matched=1
                break
            fi
        done
        if [[ "${matched}" -eq 0 && "${in_error}" -eq 1 ]]; then
            if [[ "${line}" == "" || "${line}" == "SUMMARY:"* || "${line}" == *"SUMMARY:"* ]]; then
                echo "::${kind} title=Clang Sanitizer Report (${report_id})::${current_error}%0A${line}"
                report_id=$(( report_id + 1 ))
                status=1
                current_error=""
                in_error=0
            else
                current_error="${current_error}%0A${line}"
            fi
        fi
    done < "${output_file}"

    if [[ "${in_error}" -eq 1 && "${current_error}" != "" ]]; then
        echo "::${kind} title=Clang Sanitizer Report (${report_id})::${current_error}"
        status=1
    fi

    rm -f "${output_file}"
    [[ "${kind}" == "warning" ]] && exit 0 || exit "${status}"
}

main() {
    local SOURCE_FILES="${INPUT_SOURCE_FILES:-}"
    local SANITIZER="${INPUT_SANITIZER:-asan}"
    local EXTRA_FLAGS="${INPUT_CLANG_EXTRA_FLAGS:-}"
    local OUTPUT_BINARY="${INPUT_OUTPUT_BINARY:-a.out}"
    local TIMEOUT="${INPUT_TIMEOUT:-0}"
    local OUTPUT_FILE="sanitizer-output.log"

    if [[ -z "${SOURCE_FILES}" ]]; then
        echo "::error::source_files input is required when mode=clang."
        exit 1
    fi

    local SANITIZER_FLAGS
    SANITIZER_FLAGS=$(get_sanitizer_flags "${SANITIZER}")

    # shellcheck disable=SC2086
    clang -g ${SANITIZER_FLAGS} ${EXTRA_FLAGS} ${SOURCE_FILES} -o "${OUTPUT_BINARY}"

    set +e
    # shellcheck disable=SC2086
    timeout ${TIMEOUT} ./"${OUTPUT_BINARY}" ${INPUT_BINARY_ARGS:-} 2>"${OUTPUT_FILE}"
    set -e

    parse_sanitizer_output "${OUTPUT_FILE}"
}

main
