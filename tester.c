#include <stdio.h>

extern "C" {
int myfunction(int a, int b, int c, int d);
}

int main() {
  printf("Called fun(0,1,2,3)=%d!",myfunction(0,1,2,3));
  return 0;
}
