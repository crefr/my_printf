#include <stdio.h>
#define _cdecl __attribute__((__cdecl__))

// extern "C" int _cdecl my_printf(const char *fmt, ...);
int my_printf(const char *fmt, ...);

int main()
{
    my_printf("aboba\n");

    printf("<ret value: %d>\n",
    my_printf("1234567890 %s %x", "aaaaaaaaaa12345678901", 0xEDA));

    return 0;
}
