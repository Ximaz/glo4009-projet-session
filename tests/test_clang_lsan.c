#include <stdlib.h>

int main(void) {
    int *p = malloc(64); // memory leak, never freed
    (void)p;
    return 0;
}
