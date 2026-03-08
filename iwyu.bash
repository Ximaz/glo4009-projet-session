#!/usr/bin/env bash
set -xeu

parse_iwyu_output() {
    local output_file="${1}"
    local kind="error"
    local status=0

    if [[ "${INPUT_TREAT_ERROR_AS_WARNING}" == "true" ]]; then
        kind="warning"
    fi

    local current_file=""
    local section=""
    local adds=""
    local removes=""

    flush_file() {
        if [[ -n "${current_file}" && ( -n "${adds}" || -n "${removes}" ) ]]; then
            local message=""
            if [[ -n "${adds}" ]]; then
                message="Should add:${adds}"
            fi
            if [[ -n "${removes}" ]]; then
                [[ -n "${message}" ]] && message="${message}%0A"
                message="${message}Should remove:${removes}"
            fi
            echo "::${kind} file=${current_file},line=1,title=IWYU::${message}"
            status=1
        fi
        current_file=""
        section=""
        adds=""
        removes=""
    }

    while IFS= read -r line; do
        if [[ $line =~ ^(.+)\ should\ add\ these\ lines:$ ]]; then
            flush_file
            current_file="${BASH_REMATCH[1]}"
            section="add"
        elif [[ $line =~ ^(.+)\ should\ remove\ these\ lines:$ ]]; then
            section="remove"
        elif [[ $line =~ ^The\ full\ include-list\ for ]]; then
            section="skip"
        elif [[ $line == "---" ]]; then
            flush_file
        elif [[ -n "${line}" && -n "${section}" ]]; then
            if [[ "${section}" == "add" ]]; then
                adds="${adds}%0A  ${line}"
            elif [[ "${section}" == "remove" ]]; then
                removes="${removes}%0A  ${line}"
            fi
        fi
    done < "${output_file}"

    flush_file

    rm -f "${output_file}"
    [[ "${kind}" == "warning" ]] && exit 0 || exit "${status}"
}

main() {
    local SOURCE_FILES="${INPUT_SOURCE_FILES:-}"
    local EXTRA_FLAGS="${INPUT_CLANG_EXTRA_FLAGS:-}"
    local OUTPUT_FILE="iwyu-output.log"

    if [[ -z "${SOURCE_FILES}" ]]; then
        echo "::error::source_files input is required when mode=iwyu."
        exit 1
    fi

    : > "${OUTPUT_FILE}"

    for file in ${SOURCE_FILES}; do
        set +e
        # shellcheck disable=SC2086
        include-what-you-use ${EXTRA_FLAGS} "${file}" 2>>"${OUTPUT_FILE}"
        set -e
    done

    parse_iwyu_output "${OUTPUT_FILE}"
}

main
