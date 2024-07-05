[bits 16]
[org 0x7c00]

segment .text

global start
start:
cli ; nie mów do mnie teraz 
mov [bootsect.bootDrive], dl

mov ax, cs
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00
sti

mov dl, [bootsect.bootDrive]
xor ax, ax 
int 0x13
; DL = dysk rozruchowy
; AL = 0
jc demolka

; nie mam nic do roboty, restart bo czemu ni 
call reboot

putc:
    mov ah, 0x0e
    xor bh, bh
    int 0x10
ret

puts:
    .next:
    mov al, [si]
    mov bl, 9   ; wolniejsze niż danie tego przy wywołaniu funkcji, ale
                ; 1. co z tego? ten program ma tylko wyjść
                ; 2. w kodzie to jest 1 bajt zamiast np. 3
                ;    a że cały kod może mieć 446 bajtów, no to yyy 
                ; 3. pewniejsze
    inc si
    or al, al
    jz .yeet
    call putc
    jmp .next

    .yeet:
ret

rebootprompt: db "wciskaj co, aby reset", 0
reboot:
mov si, rebootprompt
call puts
xor ax, ax
int 0x16 ; czekaj na naciśnięcie czegoś
jmp 0xffff:0


diskerror: db "dysk w pizdu"
demolka:
mov si, diskerror
call puts
call reboot

bootsect:
.OEM:       db "WPIERDOL" ; nazwa systemu
.sectSize:  dw 0x200 ; bajty na sektor
.clustSize: db 1    ; ile sektorów?
.resSect:   dw 1      ; ile zarezerwowanych sektorów? (o ten tu)
.fatCnt:    db 2
.rootSize:  dw 224
.totalSect: dw 2880
.media:     db 0xf0
.fatSize:   dw 9
.trackSect: dw 9
.headCnt:   dw 2
.hiddenSect:dd 0
.bigSects:  dd 0
.bootDrive: db 0
.reserved:  db 0
.bootSign:  db 0x29
.volID:     db "PIWO"
.volLabel:  db "PIERDOLNIKV2"
.fsType:    db "FAT16   "

times 510 - ($ - $$) db 0
dw 0xaa55