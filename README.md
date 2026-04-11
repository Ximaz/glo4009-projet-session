# Code Quality Checker Action

A GitHub Action for checking your memory management using [Valgrind](https://valgrind.org).

This Action will check for :
- un`free`'d memory,
- invalid `read` or `write` operations,
- un`close`'d file descriptors (files and sockets),
- invalid usage of `free`, `delete`, `delete []` or `realloc`,
- uninitialised `syscall` params,
- overlaps between sources and destinations for `memcpy`, `memmove`, etc...,
- `fishy` arguments (possibly negative values) for `unsigned` expected,
- memory allocation with a size of `0`,
- invalid alignment values.

If you want to have more details about the errors this Action supports, you can
check the [`4.2. Explanation of error messages from Memcheck`](https://valgrind.org/docs/manual/mc-manual.html) section.

# Usage

```yml
-   uses: ./
    with:
        # Tool to use: 'valgrind' or 'clang-static-analyzer'.
        #
        # Default: "valgrind"
        mode: "valgrind"

        # Either absolute or reative path to the binary you want to check the
        # memory on.
        binary_path: ""

        # A string containing all the arguments to pass the the binary when it
        # gets checked by Valgrind.
        #
        # Default: ""
        binary_args: ""

        # The value of the `LD_LIBRARY_PATH` environment variable so that the
        # binary can be executed with your custom libraries, if any.
        #
        # Default: ""
        ld_library_path: ""

        # Redzone size used by Valgrind. It represents the blocks that Valgrind
        # will check before, and after any allocated pointer so that it will
        # look if you're trying to operate on those bytes, which you are not
        # supposed to.
        #
        # Default: 16
        redzone_size: 16

        # Whether or not to track unclosed file descriptors.
        # Default: true
        track_file_descriptors: true

        # Whether or not to treat error as warning. This implies that, if set
        # to true, then the action will not exit with an error status, even if
        # Valgrind found issues during the binary execution. Also, this implies
        # that in your workflow summary, you will see warning annotations
        # instead of error ones.
        #
        # Default: false
        treat_error_as_warning: false

        # Valgrind suppressions. If specified, the content will be written into
        # a local file which will be passed to Valgrind. It represents a set of
        # specific checks to avoid. For instance, you can avoid checks for a
        # specific function, inside a specific program or library, etc...
        # Foe more detail, you can check the `2.5. Suppressing errors` section
        # on the Valgrind's documentation :
        # https://valgrind.org/docs/manual/manual-core.html
        #
        # For each found error by Valgrind, a generated suppression will be
        # logged inside your workflow's logs. That way, you will be able to see
        # if any dependency, unrelated to your implementation, is faulty for
        # not free'ing it's own memory or file descriptors.
        #
        # Generally, you want to avoid using this because you may tend to use
        # it badly in order to suppress errors about your own implemnetations,
        # so be careful.
        #
        # Default: ""
        #
        # The example below showcases how to avoid checking for the `free`
        # function, inside the `main` function.
        valgrind_suppressions: |
            {
                DontCheckFreeInMain
                Memcheck:Free
                fun:free
                fun:main
            }

        # Whether or not Valgrind should be verbose. It may be useful in case
        # you want to debug things.
        #
        # Default: false
        verbose: false

        # Limit the amount of time Valgrind runs before stopping the binary,
        # specified in floating point with an optional suffix. A duration of 0
        # disables the timeout.
        #
        # This can be useful to test or bound a long-running process.
        #
        # Optional suffix:
        # - 's' for seconds (the default)
        # - 'm' for minutes
        # - 'h' for hours
        # - 'd' for days
        #
        # Default: 0s
        timeout: 0s
```

---

# Clang Static Analyzer

A GitHub Action for static analysis of your C/C++ source files using
[Clang Static Analyzer](https://clang-analyzer.llvm.org/).

This Action will check for :
- memory leaks (heap-allocated objects never released),
- null pointer dereferences,
- use of uninitialized values,
- dead code and unreachable paths,
- invalid usage of C APIs (e.g. `malloc`/`free` mismatches),
- division by zero.

If you want to have more details about the checks this Action supports, you can
check the [available checkers](https://clang-analyzer.llvm.org/available_checks.html) section.

# Usage

```yml
-   uses: ./
    with:
        # Tool to use: 'valgrind' or 'clang-static-analyzer'.
        #
        # Default: "valgrind"
        mode: "clang-static-analyzer"

        # Space-separated list of C/C++ source files to analyze.
        # This input is required when mode=clang-static-analyzer.
        source_files: "main.c utils.c"

        # Extra flags to forward to `clang --analyze`.
        # Useful for specifying include paths or defines,
        # e.g. "-I./include -DDEBUG".
        #
        # Default: ""
        clang_extra_flags: ""

        # Whether or not to treat error as warning. This implies that, if set
        # to true, then the action will not exit with an error status, even if
        # the analyzer found issues during the source analysis. Also, this
        # implies that in your workflow summary, you will see warning
        # annotations instead of error ones.
        #
        # Default: false
        treat_error_as_warning: false
```

---

# Local Testing

Build the image:
```bash
docker build -t code-quality-checker .
```

Test with Clang Static Analyzer:
```bash
docker run --rm -v "$PWD/tests:/src" -e INPUT_MODE=clang-static-analyzer -e INPUT_SOURCE_FILES=/src/test_invalid_read.c -e INPUT_TREAT_ERROR_AS_WARNING=false code-quality-checker
```

Test with Valgrind:
```bash
docker run --rm -v "$(pwd)/tests:/src" -v "/tmp:/tmp" --entrypoint gcc code-quality-checker -g /src/test_no_free.c -o /tmp/test_no_free
```
```bash
docker run --rm -v "/tmp:/tmp" -e INPUT_MODE=valgrind -e INPUT_BINARY_PATH=/tmp/test_no_free -e INPUT_REDZONE_SIZE=16 -e INPUT_TRACK_FILE_DESCRIPTORS=true -e INPUT_TREAT_ERROR_AS_WARNING=false -e INPUT_VERBOSE=false -e INPUT_TIMEOUT=0 -e INPUT_VALGRIND_SUPPRESSIONS="" -e INPUT_LD_LIBRARY_PATH="" -e INPUT_BINARY_ARGS="" code-quality-checker
```
