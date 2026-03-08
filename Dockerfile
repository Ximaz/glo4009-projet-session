FROM debian:stable

RUN apt update -y                              \
    && apt upgrade -y                          \
    && apt install -y build-essential valgrind clang

COPY entrypoint.bash /root/entrypoint.bash
COPY valgrind.bash /root/valgrind.bash
COPY clang.bash /root/clang.bash

ENTRYPOINT [ "/root/entrypoint.bash" ]
