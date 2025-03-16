BUFFER_LEN equ 128

; my_printf(const char * fmt, ...)
global my_printf

section .text

;================================================
;--------------------------------------
; Trampolin for my_printf_cdecl
; receives args in System V ABI format
; then calls my_printf_cdecl;
; Destr: rax
;--------------------------------------
my_printf:
        pop rax

        push r9
        push r8
        push rcx
        push rdx
        push rsi
        push rdi

        push rax

        call my_printf_cdecl
        pop rdi
        add rsp, 6*8
        jmp rdi
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
        push rbp
        lea rbp, 24[rsp]

        push rbx

        lea rbx, [buffer]
        dec rbx                 ; buf_ptr = &buffer - 1

        mov rsi, [rbp]
        dec rsi                 ; fmt_ptr = &fmt - 1

        add rbp, 8              ; to the next arg

    .main_loop:
        inc rsi                 ; fmt_ptr++
        inc rbx                 ; buf_ptr++

        cmp BYTE [rsi], '%'     ; if (*fmt_ptr == '%')
        je .percent

        mov al, BYTE [rsi]
        mov BYTE [rbx], al
        jmp .loop_end

    .percent:
        call handle_percent

    .loop_end:
        cmp BYTE [rsi], 0        ; while (*fmt_ptr != 0)
        jne .main_loop

        lea rsi, [buffer]

        mov rdx, rbx
        sub rdx, rsi

        call write_buffer

        mov rax, rdx            ; rax = strlen(fmt)

        pop rbx
        pop rbp
        ret
;================================================


;================================================
;--------------------------------------
; Handles % symbol in fmt string
; Entry:
;   rsi = current addr in fmt (on the % symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
; Return:
; Destr: rdx rax rsi rbx rbp
;--------------------------------------
handle_percent:
        inc rsi             ; to the next symbol
        mov dl, BYTE [rsi]

        cmp dl, 0
        je .default

        cmp dl, 's'
        je handle_s

        cmp dl, 'd'
        je handle_d

        cmp dl, 'u'
        je handle_u

        cmp dl, 'o'
        je handle_o

        cmp dl, 'x'
        je handle_x

        cmp dl, 'b'
        je handle_b

    .default:
        mov BYTE [rbx], '%'

        ret
;================================================


;================================================
;--------------------------------------
; Handles %s specification
; Entry:
;   rsi = current addr in fmt (on the s symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
; Return:
; Destr:
;--------------------------------------
handle_s:
        mov rdi, [rbp]
        call my_strlen      ; rax = strlen(arg_str)

        call my_strncpy
        add rbx, rax        ; buf_ptr += strlen(arg_str)

        dec rbx
        add rbp, 8

        ret
;================================================


;================================================
;--------------------------------------
; Set of functions that handles %b, %o and %x
; Entry:
;   rsi = current addr in fmt (on the b, o or x symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
; Return: -
; Destr:
;--------------------------------------
handle_b:
        mov cl, 1
        jmp render_b_o_x

handle_o:
        mov cl, 3
        jmp render_b_o_x

handle_x:
        mov cl, 4
       ;jmp render_b_o_x

render_b_o_x:
        push rax
        push rdx

        lea r11, [num_buf]
        mov eax, [rbp]

        mov ch, -1
        shl ch, cl
        not ch                  ; dl = b0...01...1, cl = num of 1

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
        mov BYTE [r11], dl
        inc r11

        shr eax, cl

        test eax, eax
        jnz .print_loop

        call from_num_to_buf

        add rbp, 8

        pop rdx
        pop rax

        ret
;================================================


;================================================
;--------------------------------------
; Handles %d specification
; Entry:
;   rsi = current addr in fmt (on the d symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
; Return: -
; Destr:
;--------------------------------------
handle_d:
        push rdx
        push rax

        lea r11, [num_buf]
        mov eax, [rbp]

        test eax, 0x70000000
        jz print_unsigned

        mov BYTE [rbx], '-'
        inc rbx

        neg eax

        jmp print_unsigned

        ret
;================================================

;================================================
;--------------------------------------
; Handles %u specification
; Entry:
;   rsi = current addr in fmt (on the u symbol)
;   rbx = current addr in buffer
;   rbp = current arg pointer
;   r11 = num_buf addr
; Return: -
; Destr:
;--------------------------------------
handle_u:
        push rdx
        push rax

        lea r11, [num_buf]          ; r11 = &num_buf
        mov eax, [rbp]              ; eax = number

;   !FALLING THROUGH!
;------------------------------------
; This function is used by handle_u and handle_d
;------------------------------------
print_unsigned:
        mov edi, 10                 ; 10 - radix

    .num_loop:
        xor edx, edx                ; edx = 0 (for div)

        div edi
        add dl, '0'                 ; dl = ascii digit
        mov BYTE [r11], dl          ; into reversed buffer
        inc r11

        cmp eax, 0                  ; until number is 0
        jne .num_loop

        call from_num_to_buf

        add rbp, 8                  ; to the next arg

        pop rax
        pop rdx

        ret
;================================================


;================================================
;--------------------------------------
; Copies data from reversed num_buf to buffer
; Entry:
;   r11 = current addr num_buf
;   rbx = current arg pointer
; Return: -
; Destr:
;--------------------------------------
from_num_to_buf:
        dec rbx
    .copy_loop:                     ; copying reversed num_buf to buffer
        dec r11
        inc rbx
        mov dl, BYTE [r11]
        mov BYTE [rbx], dl

        cmp r11, num_buf
        jne .copy_loop

        ret
;================================================


;================================================
;--------------------------------------
; My realisation of strncpy
; Entry:
;   rbx = dest addr
;   rdi = src addr
;   rax = num of chars to copy
; Return: -
; Destr:
;--------------------------------------
my_strncpy:
        xor    rcx, rcx
    .copy_loop:
        mov dl, [rdi + rcx]
        mov [rbx + rcx], dl

        inc rcx
        cmp rcx, rax
        jne .copy_loop

        ret
;================================================


;================================================
;--------------------------------------
; Makes syscall 0x01 (write) to print buffer
; Entry:
;   rsi = buf_addr
;   rdx = symbols to write
; Return: -
; Destr: rax, rdi
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

section .bss
    buffer      resb BUFFER_LEN
    num_buf     resb 32
