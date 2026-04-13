#include <stdlib.h>

int main(void) {
    int *buf = malloc(10 * sizeof(int));
    buf[10] = 42; // heap buffer overflow
    free(buf);
    return 0;
}
