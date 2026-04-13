#!/usr/bin/env bash
set -xeu

parse_tidy_output() {
    local output_file="${1}"
    local kind="error"
    local status=0

    if [[ "${INPUT_TREAT_ERROR_AS_WARNING}" == "true" ]]; then
        kind="warning"
    fi

    local pending_annotation=""
    local pending_file=""
    local pending_line=""
    local pending_col=""
    local pending_message=""

    flush_annotation() {
        if [[ -n "${pending_annotation}" ]]; then
            echo "::${kind} file=${pending_file},line=${pending_line},col=${pending_col},title=Clang-Tidy::${pending_message}"
            status=1
        fi
        pending_annotation=""
        pending_file=""
        pending_line=""
        pending_col=""
        pending_message=""
    }

    while IFS= read -r line; do
        if [[ $line =~ ^(.+):([0-9]+):([0-9]+):\ (warning|error):\ (.+)$ ]]; then
            flush_annotation
            pending_annotation="1"
            pending_file="${BASH_REMATCH[1]}"
            pending_line="${BASH_REMATCH[2]}"
            pending_col="${BASH_REMATCH[3]}"
            pending_message="${BASH_REMATCH[5]}"
        elif [[ $line =~ ^(.+):([0-9]+):([0-9]+):\ note:\ (.+)$ ]]; then
            if [[ -n "${pending_annotation}" ]]; then
                pending_message="${pending_message}%0A${BASH_REMATCH[4]}"
            fi
        fi
    done < "${output_file}"

    flush_annotation

    rm -f "${output_file}"
    [[ "${kind}" == "warning" ]] && exit 0 || exit "${status}"
}

main() {
    local SOURCE_FILES="${INPUT_SOURCE_FILES:-}"
    local EXTRA_FLAGS="${INPUT_CLANG_EXTRA_FLAGS:-}"
    local CHECKS="${INPUT_CLANG_TIDY_CHECKS:-}"
    local OUTPUT_FILE="clang-tidy-output.log"

    if [[ -z "${SOURCE_FILES}" ]]; then
        echo "::error::source_files input is required when mode=clang-tidy."
        exit 1
    fi

    local CHECKS_FLAG=""
    if [[ -n "${CHECKS}" ]]; then
        CHECKS_FLAG="-checks=${CHECKS}"
    fi

    set +e
    # shellcheck disable=SC2086
    clang-tidy ${CHECKS_FLAG} ${SOURCE_FILES} -- ${EXTRA_FLAGS} >"${OUTPUT_FILE}" 2>&1
    set -e

    parse_tidy_output "${OUTPUT_FILE}"
}

main
