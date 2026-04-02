#include <pthread.h>

int shared = 0;

void *thread_func(void *arg) {
    (void)arg;
    shared = 42; // data race
    return NULL;
}

int main(void) {
    pthread_t t;
    pthread_create(&t, NULL, thread_func, NULL);
    shared = 7; // data race
    pthread_join(t, NULL);
    return 0;
}
