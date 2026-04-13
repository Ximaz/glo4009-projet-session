#include <stdlib.h>
#include <string.h>

void suspicious_semicolon(int x) {
    if (x > 0);
    {
        malloc(10);
    }
}

int redundant_expression(int x) {
    if (x == x) {
        return 1;
    }
    return 0;
}

int main(void) {
    suspicious_semicolon(1);
    return redundant_expression(42);
}
