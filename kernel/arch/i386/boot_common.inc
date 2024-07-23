; minimalne README
; system plików: ISO 9660 + Rock Ridge
; (czyli liveCD)

; konwencja: 
; za blokami opisanymi
; - koniec -
; można stawiać cokolwiek
; Pozostałych bloków bym nie ruszał
; x86, w odróżnieniu od np. C, 
; używa mechaniki "spadania" między funkcjami
; (IP leci do przodu i tyle)
; i możesz sobie sporo zepsuć, tasując rzeczy

; opisywanie funkcji:
; (opis)
; przyjmuje:
; XX - co przyjmuje
; zwraca:
; XX - co zwraca
; zaśmieca:
; XX - jakich rejestrów używa, które nie są argumentami?
; flagi: 
; XF - kiedy (jeśli to nie oczywiste)?



; --- makra ---

; zgłoś coś i się przy tym wywal
; przyjmuje: wskaźnik do stringa
%macro ERROR 0-1 byeInfo
REPORT %1
call reboot
%endmacro

%macro REPORT 0-1 si
    push si
    mov si, %1
    call puts
    pop si
%endmacro
; ------

; drukuje jeden znak na ekranie
; przyjmuje: znak do wyplucia
; zwraca: nic
; zaśmieca: BH
; flagi: oby nie
; może zaśmiecić BP, jeśli BIOS jest robiony po taniości
putc:
    push bx
    mov ah, 0x0e
    xor bh, bh
    int 0x10
    pop bx
    ret


; drukuje stringa na ekranie
; przyjmuje: wskaźnik do stringa
; zwraca: nic
; zaśmieca: AL, BL
; flagi: ZF
puts:
    push ax
    push bx
    .next:
    mov al, [si]
    mov bl, 9   ; wolniejsze niż danie tego przy wywołaniu funkcji, ale
                ; 1. co z tego? ten program ma tylko wyjść
                ; 2. w kodzie to jest 1 bajt zamiast np. 3
                ;    a że cały kod może mieć 446* bajtów, no to yyy 
                ; 3. pewniejsze
                ; *zależy od użytego systemu plików, systemu rozruchu itd.
                ; **w tym szczególnym przypadku LiveCD rozruch może mieć 2046 bajtów
    inc si
    or al, al
    jz .yeet
    call putc
    jmp .next

    .yeet:
    pop bx
    pop ax
    ret


reboot:
REPORT rebootInfo
xor ax, ax
int 0x16 ; czekaj na naciśnięcie czegoś
jmp 0xffff:0



; zrzuć system z rowerka i go nie resetuj
; nie wiem wsm, do debugowania może się przyda?
%macro CRASH 0
REPORT byeInfo
cli
hlt 
; tak, to wystarczy :)
%endmacro




; stałe
rebootInfo: db 13, 10, "wciskaj co, aby reset", 0
loadingInfo: db "Wczytywanie...", 13, 10, 0
diskErrorInfo: db "dysk w pizdu", 13, 10, 0
noStage2Info: db "Brakuje reszty bootloadera, dalej nie jade", 13, 10, 0  
byeInfo: db "ROZDUPCAM", 13, 10, 0 