#include <Vision/Hide.h>

int main() { return Vision::hidden(-1, 0) && !Vision::hidden(1, 1) ? 0 : 1; }
