// C++ test: triggers AddressSanitizer (heap-use-after-free)
int main() {
    int *p = new int(42);
    delete p;
    return *p; // heap-use-after-free
}
