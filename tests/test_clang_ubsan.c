#include <limits.h>

int main(void) {
    int x = INT_MAX;
    x += 1; // signed integer overflow
    return 0;
}
