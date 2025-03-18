#include <stdio.h>
#define _cdecl __attribute__((__cdecl__))

// extern "C" int _cdecl my_printf(const char *fmt, ...);
int my_printf(const char *fmt, ...);

int main()
{
    // printf("<ret value: %d>\n",
    // my_printf("1234567890 %s %x", "aaaaaaaaaa12345678901", ));

    int printed_chars = my_printf("7 + 18 = %d, %s %c %s = %d\n%s --> %s\n%d %s %x %d%%%c%b\n", 25, "7", '*', "-8", -56,
                                  "This is argument from stack", "another one\n", -1, "love", 3802, 100, 33, 126);
    printf("<ret value: %d>\n", printed_chars);

    return 0;
}
