#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int *p = malloc(sizeof(int));
    if (*p) // use of uninitialized memory
        printf("uninitialized\n");
    free(p);
    return 0;
}
