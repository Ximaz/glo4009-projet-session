#!/usr/bin/env bash
set -xeu

parse_analyzer_output() {
    local output_file="${1}"
    local clang_exit_code="${2}"
    local kind="error"
    local status=0
    local report_id=1

    if [[ "${INPUT_TREAT_ERROR_AS_WARNING:-false}" == "true" ]]; then
        kind="warning"
    fi

    local current_file=""
    local current_line=""
    local current_col=""
    local current_message=""
    local has_pending=0
    local found_report=0

    flush_report() {
        if [[ "${has_pending}" -eq 1 ]]; then
            echo "::${kind} file=${current_file},line=${current_line},col=${current_col},title=Clang Static Analyzer Report (${report_id})::${current_message}"
            report_id=$((report_id + 1))
            status=1
            found_report=1
        fi
        current_file=""
        current_line=""
        current_col=""
        current_message=""
        has_pending=0
    }

    while IFS= read -r line; do
        if [[ "${line}" =~ ^(.+):([0-9]+):([0-9]+):[[:space:]](warning|error):[[:space:]](.+)$ ]]; then
            flush_report
            current_file="${BASH_REMATCH[1]}"
            current_line="${BASH_REMATCH[2]}"
            current_col="${BASH_REMATCH[3]}"
            current_message="${BASH_REMATCH[5]}"
            has_pending=1
        elif [[ "${line}" =~ ^(.+):([0-9]+):([0-9]+):[[:space:]]note:[[:space:]](.+)$ ]]; then
            if [[ "${has_pending}" -eq 1 ]]; then
                current_message="${current_message}%0A${BASH_REMATCH[4]}"
            fi
        fi
    done < "${output_file}"

    flush_report
    rm -f "${output_file}"

    if [[ "${found_report}" -eq 0 && "${clang_exit_code}" -ne 0 ]]; then
        echo "::error::clang static analyzer failed to run."
        exit "${clang_exit_code}"
    fi

    if [[ "${kind}" == "warning" ]]; then
        exit 0
    fi
    exit "${status}"
}

main() {
    local SOURCE_FILES="${INPUT_SOURCE_FILES:-}"
    local EXTRA_FLAGS="${INPUT_CLANG_EXTRA_FLAGS:-}"
    local OUTPUT_FILE="clang-static-analyzer.log"

    if [[ -z "${SOURCE_FILES}" ]]; then
        echo "::error::source_files input is required when mode=clang-static-analyzer."
        exit 1
    fi

    set +e
    # shellcheck disable=SC2086
    clang --analyze \
        -Xanalyzer -analyzer-output=text \
        ${EXTRA_FLAGS} \
        ${SOURCE_FILES} \
        2> "${OUTPUT_FILE}"
    local clang_exit_code=$?
    set -e

    parse_analyzer_output "${OUTPUT_FILE}" "${clang_exit_code}"
}

main