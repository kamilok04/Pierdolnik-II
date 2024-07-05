[bits 16]
global kernel_main:function
kernel_main:
jmp $
ret


; wyświetla se znaczek
; wchodzi:
; AL - znak do zrobienia
; AH - polecenie (wyświetl znak)
; BH - strona (0)
; BL - kolor
; wychodzi: nic


putc:
    mov ah, 0x0e
    xor bh, bh
    int 0x10
ret

puts:
    .next:
    mov al, [si]
    inc si
    or al, al
    jz .yeet
    call putc
    jmp .next

    .yeet:
ret
