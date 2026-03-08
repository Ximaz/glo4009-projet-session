#!/usr/bin/env bash
set -xeu

MODE="${INPUT_MODE:-valgrind}"

case "${MODE}" in
    valgrind)
        exec /root/valgrind.bash
        ;;
    clang)
        exec /root/clang.bash
        ;;
    *)
        echo "::error::Unknown mode '${MODE}'. Must be 'valgrind' or 'clang'."
        exit 1
        ;;
esac
