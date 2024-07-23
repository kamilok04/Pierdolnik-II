; drukuje wartość EAX na ekranie
; przyjmuje: nic
; zwraca: nic
; zaśmieca: nic
; flagi: CF (!)
debugReg:
    std
    ; .msg: db "EAX=0x        ", 13, 10, 0
    ; hehe, z tym stringiem to śmieszna sprawa jest
    ; przypomnę, że to plik BIN, czyli nie ma tutaj pojęcia "segmentów"
    ; przypomnę też, że to jeszcze tryb rzeczywisty i nie ma pojęcia "ochrony"
    ; tak, system próbował wykonać stringa jak kod, a ja się dziwiłem że nie działa
    ; :)
    push eax
    push ebx
    push cx
    push di

    mov di, (.msg+13)
    mov cx, 8
    mov ebx, eax
    .next:
    test cx, cx
    jz .done

    mov al, bl
    and al, 0b1111
    add al, 0x90
    daa
    adc al, 0x40
    daa
    stosb
    shr ebx, 4

    dec cx
    test cx, cx
    jnz .next
    
.done:
    sub di, 5
    REPORT di
    pop di
    pop cx
    pop ebx
    pop eax
    cld
ret
.msg: db "EAX=0x        ", 13, 10, 0

; stałe
stage2Info: db "Pierdolnik2, czekaj...", 13, 10, 0
unhandledIntInfo: db "Nieosblugiwany wyjatek, dalej nie jade", 13, 10, 0
breakpointInfo: db "INT3 - przystanek na zadanie", 13, 10, 0


; obsługa wyjątków
; co tak wcześnie? za parę linijek się wyjaśni :)
int3handler:
    pop ax
    REPORT breakpointInfo
    call debugReg
    push ax
    jmp int_done

int6handler:
    pop ax
    cmp ax, checkCPUID
    push ax
    je .CPUIDFailed
    ; no nie
    ; jeśli to nie CPUID, to coś jest bardzo źle zrobione
    call debugReg
    ERROR unhandledIntInfo
    CRASH
    ; - koniec -
.CPUIDFailed:
    dec byte[infoTable.CPUIDPresent]
    jmp int_done

int_done:
    mov al, 0x20 ; powiedz PICowi, żeby się zamknął
    out 0x20, al
    iret


; informacje dla przyszłego jądra
infoTable:
.CPUIDPresent: db 1