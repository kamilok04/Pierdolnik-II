[bits 16]
[org 0x1800]

segment .text
global round2

jmp round2
nop

%include "boot_common.inc"
%include "boot_helper.inc"


round2:

; jestem w drugiej fazie bootloadera,
; nie muszę się jakoś bardzo martwić o miejsce dyskowe

; co trzeba zrobić?
;
; włączyć tryb chroniony (a może i bezpośrednio długi)

; zainstaluj tę "obsługę"
mov dword[0x18], int6handler
mov dword[0xc], int3handler

REPORT stage2Info
 
; czy obługa wyjątków działa?
int3


; czy CPUID jest?
; jeśli procesor się wysypie, to nie ma
; nie żartuję, to jest standardowa metoda
checkCPUID: CPUID

CRASH





