BUFFER_LEN equ 64

; my_printf(const char * fmt, ...)
global my_printf

section .text

;================================================
;--------------------------------------
; Trampolin for my_printf_cdecl
; receives args in System V ABI format
; then calls my_printf_cdecl;
;--------------------------------------
my_printf:
        pop rax             ; caller addr

        push r9
        push r8
        push rcx
        push rdx
        push rsi
        push rdi

        push rax            ; caller addr

        jmp my_printf_cdecl
;================================================


;================================================
;--------------------------------------
; my_printf_cdecl(const char * fmt, ...)
; My realisation of printf
; Entry:
;   args in cdecl format
; Return:
;   num of symbols printed
; Destr: rax,
;--------------------------------------
my_printf_cdecl:
        push rbp                ; saving rbp for caller
        lea rbp, 16[rsp]        ; rbp is on the 1st arg

    ; saving other registers for caller
        push rbx
        push r12
        push r13
        push r14
        push r15
    ;----------------------------------

    ; allocating buffer on stack
        sub rsp, BUFFER_LEN
        mov r14, rsp
    ;---------------------------

        xor r13, r13            ; num of symbols printed = 0

        xor rbx, rbx            ; index = 0
        dec rbx                 ; index = -1 (for main cycle)

        mov r8, [rbp]
        dec r8                  ; fmt_ptr = &fmt - 1

        add rbp, 8              ; to the next arg (after fmt)

    ;--- scanning loop ---
    .main_loop:
        inc r8                  ; fmt_ptr++
        inc rbx                 ; buf_ptr++

        cmp BYTE [r8], '%'      ; if (*fmt_ptr == '%')
        je .percent

        cmp rbx, BUFFER_LEN     ; checking for overflow
        jb .do_not_flush
        call flush_buffer
    .do_not_flush:

        mov al, BYTE [r8]
        mov BYTE [r14 + rbx], al
        jmp .loop_end

    .percent:
        call handle_percent

    .loop_end:
        cmp BYTE [r8], 0        ; while (*fmt_ptr != 0)
        jne .main_loop
    ;---------------------

        call flush_buffer

        mov rax, r13            ; returning rax = num of symbols printed

        add rsp, BUFFER_LEN     ; deallocating buffer

    ; restoring registers for caller
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx
        pop rbp
    ;-------------------------------

    ;--- restoring stack and returning ---
        pop rdi                 ; caller addr
        add rsp, 6*8            ; restoring stack
        jmp rdi                 ; ret
    ;-------------------------------------
;================================================


;================================================
;--------------------------------------
; Handles % symbol in fmt string
; Entry:
;   r8 = current addr in fmt (on the % symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
; Return:
;   r8++
; Destr: rdx rax r8 rbx rbp
;--------------------------------------
handle_percent:
        xor rdx, rdx

        inc r8                 ; to the next symbol
        mov dl, BYTE [r8]

        sub dl, 'b'

        cmp dl, 'u'             ; if (symbol > 'u' || symbol < 'a')
        ja .default             ; then default

        jmp JMP_TABLE[rdx*8]    ; switch(symbol)
        ; jump table is in .rodata at the end of file

    .default:
        mov BYTE [r14 + rbx], '%'

        ret
;================================================


;================================================
;--------------------------------------
; Handles %c specification
; Entry:
;   r8 = current addr in fmt (on the s symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
; Return:
;   rbp is on the next arg
; Destr: al rbp
;--------------------------------------
handle_c:
        mov al, BYTE [rbp]
        mov BYTE [r14 + rbx], al

        add rbp, 8

        ret
;================================================


;================================================
;--------------------------------------
; Handles %s specification
; Entry:
;   r8 = current addr in fmt (on the s symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
; Return:
;   rbx = new addr in buffer
;   rbp = next arg pointer
; Destr: rdi rbx rbp rsi rdx rax rcx r12
;--------------------------------------
handle_s:
        mov rdi, [rbp]
        call my_strlen      ; rax = strlen(arg_str)

    ; if (strlen > BUFFER_LEN)
        cmp rax, BUFFER_LEN
        ja .too_long_str

    ; --- overflow check ---
        lea rcx, [rbx + rax]    ; rcx = new index in buffer (hypothetically)

        cmp rcx, BUFFER_LEN
        jb .not_flushing

        push rax
        push rdi
        call flush_buffer
        pop rdi           ; restoring rdi
        pop rax
    .not_flushing:
    ; --- overflow check ---
        lea rsi, [r14 + rbx]
        call my_strncpy
        add rbx, rax        ; buf_ptr += strlen(arg_str)

        dec rbx
        add rbp, 8

        ret

    ; if too long then flushing buffer and syscall
    .too_long_str:
        push rax
        call flush_buffer
        pop rax

        dec rbx

        mov rsi, [rbp]
        mov rdx, rax

        add r13, rax

        call write_buffer

        add rbp, 8

        ret
;================================================


;================================================
;--------------------------------------
; Set of functions that handles %b, %o and %x
; Entry:
;   r8 = current addr in fmt (on the b, o or x symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
; Return:
;   rbp - on the next arg
; Destr: rcx, r9, r11, rbp
;--------------------------------------
handle_b:
        mov cl, 1
        jmp print_b_o_x

handle_o:
        mov cl, 3
        jmp print_b_o_x

handle_x:
        mov cl, 4
       ;jmp print_b_o_x

print_b_o_x:
        push rax
        push rdx

    ; --- overflow check ---
        xchg rcx, r9                    ; saving rcx in r9

        cmp rbx, BUFFER_LEN - 32        ; 32 is max len of %b
        jb .not_flushing

        call flush_buffer
    .not_flushing:

        xchg rcx, r9
    ; ----------------------

        xor dl, dl

    ; allocating buffer for number in stack
        sub rsp, 32             ; 32 is max len of %b specification
        mov rsi, rsp            ; r11 = &num_buf
    ; -------------------------------------

        xor r11, r11            ; r11 = num_buf_index = 0

        mov eax, [rbp]

        mov ch, -1
        shl ch, cl
        not ch                  ; ch = b0...01...1, cl = num of 1

    .print_loop:
        mov dl, ch
        and dl, al

        add dl, '0'

    ;--- for cl = 4 (hexadecimal) ---
        cmp dl, '9'
        jbe .not_letter
        add dl, 'a' - '0' - 10
    ;--------------------------------

    .not_letter:
        mov BYTE [rsi + r11], dl
        inc r11

        shr eax, cl

        test eax, eax
        jnz .print_loop

        call from_num_to_buf

        add rbp, 8

        add rsp, 32                 ; deallocating number buffer

        pop rdx
        pop rax

        ret
;================================================


;================================================
;--------------------------------------
; Handles %d specification
; Entry:
;   r8 = current addr in fmt (on the d symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
;   r14 = buffer start addr
; Return:
;   rbx = new addr in buffer
; Destr: r11, rbx, rdi
;--------------------------------------
handle_d:
        push rdx
        push rax

    ; --- overflow check ---
        cmp rbx, BUFFER_LEN - 11        ; 11 is len of -INT_MAX
        jb .not_flushing

        call flush_buffer
    .not_flushing:
    ; --- overflow check ---

        mov eax, [rbp]

        test eax, 0x70000000
        jz print_unsigned

        mov BYTE [r14 + rbx], '-'
        inc rbx

        neg eax

        jmp print_unsigned
;================================================


;================================================
;--------------------------------------
; Handles %u specification
; Entry:
;   r8 = current addr in fmt (on the u symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
;   r11 = num_buf addr
; Return: -
; Destr: r11, rbx, rdi
;--------------------------------------
handle_u:
        push rdx
        push rax

    ; --- overflow check ---
        cmp rbx, BUFFER_LEN - 10        ; 10 is len of UINT_MAX
        jb .not_flushing

        call flush_buffer
    .not_flushing:
    ; --- overflow check ---

        mov eax, [rbp]              ; eax = number

;   !!!FALLING THROUGH!!!
;------------------------------------
; This function is used by handle_u and handle_d
;------------------------------------
print_unsigned:
    ; allocating buffer for number in stack
        sub rsp, 32             ; 32 is max len of %b specification
        mov rsi, rsp            ; rsi = &num_buf
    ; --------------------------------------
        xor r11, r11            ; r11 = index_in_num_buf = 0

        mov edi, 10                 ; 10 - radix

    .num_loop:
        xor edx, edx                ; edx = 0 (for div)

        div edi
        add dl, '0'                 ; dl = ascii digit
        mov BYTE [rsi + r11], dl          ; into reversed buffer
        inc r11

        cmp eax, 0                  ; until number is 0
        jne .num_loop

        call from_num_to_buf

        add rbp, 8                  ; to the next arg

        add rsp, 32                 ; deallocating number buffer

        pop rax
        pop rdx

        ret
;================================================


;================================================
;--------------------------------------
; Copies data from reversed num_buf to buffer
; Entry:
;   rsi = addr of num_buf
;   r11 = index in num_buf
;   rbx = current arg pointer
; Return:
;   rbx = new addr in buffer
;   r11 = new addr in num_buf
; Destr: rbx, r11, rdx
;--------------------------------------
from_num_to_buf:
        dec rbx
    .copy_loop:                     ; copying reversed num_buf to buffer
        dec r11
        inc rbx
        mov dl, BYTE [rsi + r11]
        mov BYTE [r14 + rbx], dl

        cmp r11, 0
        jne .copy_loop

        ret
;================================================


;================================================
;--------------------------------------
; My realisation of strncpy
; Entry:
;   rsi = dest addr
;   rdi = src addr
;   rax = num of chars to copy
; Return: -
; Destr: rcx, rdx
;--------------------------------------
my_strncpy:
        xor    rcx, rcx
    .copy_loop:
        mov dl, [rdi + rcx]
        mov [rsi + rcx], dl

        inc rcx
        cmp rcx, rax
        jne .copy_loop

        ret
;================================================


;================================================
;--------------------------------------
; Flushes buffer from .bss
; Entry:
;   r14 = buffer addr
;   rbx = current index in buffer
;   r13 = num of printed chars
; Return:
;   r13 = new num of printed chars
;   rbx = 0
; Destr: rax, rdi, r8, rdx, rbx
;--------------------------------------
flush_buffer:
        mov rsi, r14        ; str = buf_adr

        mov rdx, rbx
        add r13, rdx

        mov rax, 0x01       ; write(rdi, r8, rdx)
        mov rdi, 1          ; stdout
        syscall

        xor rbx, rbx        ; to the start

        ret
;================================================


;================================================
;--------------------------------------
; Makes syscall 0x01 (write) to print buffer
; Entry:
;   rsi = buf_addr
;   rdx = symbols to write
; Return: -
; Destr: rax, rdi, rsi, rdx
;--------------------------------------
write_buffer:
        mov rax, 0x01       ; write(rdi, rsi, rdx)
        mov rdi, 1          ; stdout
        syscall

        ret
;================================================


;================================================
;--------------------------------------
; My realisation of strlen
; Entry:
;   rdi = str addr (ending with \0)
; Return:
;   rax = num of symbols
; Destr: rax
;--------------------------------------
my_strlen:
        mov rax, rdi
        dec rax
    .str_loop:
        inc rax

        cmp BYTE [rax], 0
        jne .str_loop

        sub rax, rdi

        ret
;================================================


section .rodata
;==================================
; Jump table for handle_percent function
; range is 'b' to 'x'
;==================================
JMP_TABLE:
    align 8

    dq handle_b                 ; 'b'
    dq handle_c                 ; 'c'
    dq handle_d                 ; 'd'

    ; e f g h i j k l m n
    dq 'o' - 'd' - 1 dup handle_percent.default
    dq handle_o                 ; 'o'

    ; p q r
    dq 's' - 'o' - 1 dup handle_percent.default
    dq handle_s                 ; 's'

    ; t
    dq handle_percent.default
    dq handle_u

    ; v w
    dq 'x' - 'u' - 1 dup handle_percent.default
    dq handle_x

    ; y z are out of range
;==================================
