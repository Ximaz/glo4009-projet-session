#!/usr/bin/env bash
set -xeu

MODE="${INPUT_MODE:-valgrind}"

case "${MODE}" in
    valgrind)
        exec /root/valgrind.bash
        ;;
    clang-static-analyzer)
        exec /root/clang_static_analyzer.bash
        ;;
    *)
        echo "::error::Unknown mode '${MODE}'. Must be 'valgrind' or 'clang-static-analyzer'."
        exit 1
        ;;
esac