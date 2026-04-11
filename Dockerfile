FROM debian:stable

RUN apt update -y                              \
    && apt upgrade -y                          \
    && apt install -y build-essential valgrind clang

COPY valgrind.bash /root/valgrind.bash
COPY clang_static_analyzer/run_clang_static_analyzer.sh /root/clang_static_analyzer.bash
COPY entrypoint.bash /root/entrypoint.bash

ENTRYPOINT [ "/root/entrypoint.bash" ]
