FROM debian:stable

RUN apt update -y                              \
    && apt upgrade -y                          \
    && apt install -y build-essential valgrind clang clang-tidy iwyu

USER root

COPY entrypoint.bash /root/entrypoint.bash
COPY valgrind.bash /root/valgrind.bash
COPY helgrind.bash /root/helgrind.bash
COPY clang.bash /root/clang.bash
COPY clang-tidy.bash /root/clang-tidy.bash
COPY iwyu.bash /root/iwyu.bash

ENTRYPOINT [ "/root/entrypoint.bash" ]
