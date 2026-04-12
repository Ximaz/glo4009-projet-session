#!/usr/bin/env bash
set -xeu

prepare_helgrind_flags() {
    echo "--tool=helgrind"
    echo "--history-level=${INPUT_HELGRIND_HISTORY_LEVEL:-full}"

    if [[ "${INPUT_HELGRIND_TRACK_LOCKORDERS:-true}" == "true" ]]; then
        echo "--track-lockorders=yes"
    else
        echo "--track-lockorders=no"
    fi

    if [[ "${INPUT_VERBOSE:-false}" == "true" ]]; then
        echo "--verbose"
    fi
}

parse_helgrind_reports() {
    local HELGRIND_REPORTS="${1}"
    local report_id=1
    local status=0
    local error=""
    local kind="error"

    if [[ "${INPUT_TREAT_ERROR_AS_WARNING:-false}" == "true" ]]; then
        kind="warning"
    fi

    while IFS= read -r line; do
        if [[ "${line}" == *"Possible data race"* ]] \
            || [[ "${line}" == *"Conflicting access"* ]] \
            || [[ "${line}" == *"lock order"* ]] \
            || [[ "${line}" == *"pthread_mutex"* ]] \
            || [[ "${line}" == *"was first observed at"* ]] \
            || [[ "${line}" == *"Thread #"* ]]; then
            if [[ -n "${error}" ]]; then
                echo "::${kind} title=Helgrind Report '${INPUT_HELGRIND_BINARY_PATH}' (${report_id})::${error}"
                report_id=$((report_id + 1))
                status=1
            fi
            error="${line}"
        elif [[ -n "${error}" ]]; then
            if [[ "${line}" =~ ^==[0-9]+==[[:space:]]*$ ]]; then
                echo "::${kind} title=Helgrind Report '${INPUT_HELGRIND_BINARY_PATH}' (${report_id})::${error}"
                report_id=$((report_id + 1))
                error=""
                status=1
            else
                error="${error}%0A${line}"
            fi
        fi
    done < "${HELGRIND_REPORTS}"

    if [[ -n "${error}" ]]; then
        echo "::${kind} title=Helgrind Report '${INPUT_HELGRIND_BINARY_PATH}' (${report_id})::${error}"
        status=1
    fi

    rm -f "${HELGRIND_REPORTS}"
    [[ "${kind}" == "warning" ]] && exit 0 || exit "${status}"
}

main() {
    local HELGRIND_REPORTS="helgrind-reports.log"
    local HELGRIND_FLAGS
    HELGRIND_FLAGS=$(prepare_helgrind_flags)

    if [[ -z "${INPUT_HELGRIND_BINARY_PATH:-}" ]]; then
        echo "::error::helgrind_binary_path input is required when mode=helgrind."
        exit 1
    fi

    if [[ ! -f "${INPUT_HELGRIND_BINARY_PATH}" ]]; then
        echo "::error::Binary '${INPUT_HELGRIND_BINARY_PATH}' does not exist."
        exit 1
    fi

    if [[ -n "${INPUT_LD_LIBRARY_PATH:-}" ]]; then
        export LD_LIBRARY_PATH="${INPUT_LD_LIBRARY_PATH}"
    fi

    set +e
    # shellcheck disable=SC2086
    timeout ${INPUT_TIMEOUT:-0} valgrind ${HELGRIND_FLAGS} "${INPUT_HELGRIND_BINARY_PATH}" ${INPUT_HELGRIND_BINARY_ARGS:-} 2>"${HELGRIND_REPORTS}"
    set -e

    parse_helgrind_reports "${HELGRIND_REPORTS}"
}

main