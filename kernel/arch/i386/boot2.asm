[bits 16]

segment .text
global round2

jmp round2
nop

%include "boot_common.inc"

round2:

; jestem w drugiej fazie bootloadera,
; nie muszę się jakoś bardzo martwić o miejsce dyskowe

; co trzeba zrobić?
;
; włączyć tryb chroniony (a może i bezpośrednio długi)


; drogi Czytelniku
; wybacz mi następne kilka linijek

mov si, 0x7c8e
call 0:0x7c0b

mov si, 0x7ca7
call 0:0x7c0b

call 0:0x7c1a
