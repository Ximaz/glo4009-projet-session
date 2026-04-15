#!/usr/bin/env bash
set -xeu

MODE="${INPUT_MODE:-valgrind}"

case "${MODE}" in
    valgrind)
        exec /root/valgrind.bash
        ;;
    helgrind)
        exec /root/helgrind.bash
        ;;
    clang-static-analyzer)
        exec /root/clang_static_analyzer.bash
        ;;
    clang)
        exec /root/clang.bash
        ;;
    clang-tidy)
        exec /root/clang-tidy.bash
        ;;
    iwyu)
        exec /root/iwyu.bash
        ;;
    *)
        echo "::error::Unknown mode '${MODE}'. Must be 'valgrind', 'helgrind', 'clang', 'clang-tidy', 'iwyu', or 'clang-static-analyzer'."
        exit 1
        ;;
esac