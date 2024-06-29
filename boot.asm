[bits 16]
[org 0x7c00]

; chcę kolory!
xor ah, ah
mov al, 0xd
int 0x10

; ustaw tekst jak dla człowieka
mov dx, 0x0b03
xor bx, bx
mov ah, 2
int 0x10

mov si, info
call puts

jmp $
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
    mov bl, [si + colors - info]
    inc si
    or al, al
    jz .yeet
    call putc
    jmp .next

    .yeet:
ret

jmp $

info db "LEGIA TO CHUJE A LECH MISTRZ POLSKI", 0
colors
times 5 db 10
times 4 db 15
times 5 db 12
times 3 db 15
times 4 db 11
times 14 db 15
times 510 - ($ - $$) db 0
dw 0xaa55