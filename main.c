#include <stdio.h>
#define _cdecl __attribute__((__cdecl__))

// extern "C" int _cdecl my_printf(const char *fmt, ...);
int my_printf(const char *fmt, ...);

int main()
{
    printf("<ret value: %d>\n",
    my_printf("value of %s is %d\n", "bebra", 228));

    return 0;
}
