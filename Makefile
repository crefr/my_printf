FILENAME = my_printf
OBJDIR 		   = Obj/
# SRCDIR 		   = sources/
# HEADDIR 	   = headers/

CC = gcc

asm_sources = my_printf.s
c_sources 	= main.c

ASM_OBJS = $(addprefix $(OBJDIR), $(addsuffix .o, $(basename $(asm_sources))))
C_OBJS   = $(addprefix $(OBJDIR), $(addsuffix .o, $(basename $(c_sources))))

$(FILENAME): $(ASM_OBJS) $(C_OBJS)
	gcc -no-pie -o $@ $^

$(ASM_OBJS): $(asm_sources)
	nasm -f elf64 -l $(addsuffix .lst, $(basename $<)) $< -o $@

$(C_OBJS):	$(c_sources)
	$(CC) $(CFLAGS) -g3 -O0 -c $< -o $@

dump:
	objdump -d -Mintel $(FILENAME) > $(basename $(FILENAME)).disasm

clean:
	rm $(OBJDIR)*
