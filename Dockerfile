FROM debian:stable

RUN apt update -y                              \
    && apt upgrade -y                          \
    && apt install -y build-essential valgrind clang clang-tidy iwyu

COPY ./clang_static_analyzer/install_clang_static_analyzer.sh /root/install_clang_static_analyzer.sh
RUN ./install_clang_static_analyzer.sh
RUN rm install_clang_static_analyzer.sh
COPY ./clang_static_analyzer/run_clang_static_analyzer.sh /root/run_clang_static_analyzer.sh

COPY entrypoint.bash /root/entrypoint.bash
COPY valgrind.bash /root/valgrind.bash
COPY clang.bash /root/clang.bash
COPY clang-tidy.bash /root/clang-tidy.bash
COPY iwyu.bash /root/iwyu.bash

ENTRYPOINT [ "/root/entrypoint.bash" ]
