#include <pthread.h>
#include <stdio.h>

int counter = 0;

void* thread_func(void* arg) {
    for(int i=0;i<100000;i++)
        counter++;
    return NULL;
}

int main() {

    pthread_t t1,t2;

    pthread_create(&t1,NULL,thread_func,NULL);
    pthread_create(&t2,NULL,thread_func,NULL);

    pthread_join(t1,NULL);
    pthread_join(t2,NULL);

    printf("%d\n",counter);

}
