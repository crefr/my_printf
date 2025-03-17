#include <stdio.h>
#define _cdecl __attribute__((__cdecl__))

// extern "C" int _cdecl my_printf(const char *fmt, ...);
int my_printf(const char *fmt, ...);

int main()
{
    printf("<ret value: %d>\n",
    my_printf("%s", "1234567890\n1234567890\n1234567890\n1234567890\n"));

    return 0;
}
