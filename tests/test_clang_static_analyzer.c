#include <stdlib.h>

/* Test file for Clang Static Analyzer: null pointer dereference */
int main(void) {
    int *p = NULL;
    return *p;
}