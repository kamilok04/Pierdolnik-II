[bits 16]
global round2
round2:
mov al, 'A'
call putc
jmp $ - 4

putc:
    mov ah, 0x0e
    xor bh, bh
    int 0x10
ret