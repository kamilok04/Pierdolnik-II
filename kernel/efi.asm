[bits 64]
[org 0x100000] ; ?

segment .header
DOS_HEADER:
    dw 0x5a4d
    times 29 dw 0
    dd 0x80
    ; tu powinien być program MS-DOS
    times 32 dw 0
PE_HEADER:
    dd 0x4550 ; PE
    dw 0x8664 ; jak sama nazwa wskazuje, x86_64
    dw 2      ; dwie sekcje
    dd 1112477820  ; data: 02-04-2005 21:37:00
    dd 0      ; nie ma tablicy symboli
    dd 0      ; zaskakujące, ale nieistniejąca tablica jest pusta
    dw headerSize     
    dw 0x1002 ; obraz, bootowalny, tyle

headerSize EQU HEADER_END - HEADER_STANDARD

HEADER_STANDARD:
    dw 0x020b ; PE32+ prosim, rax jest fajne
    dw 0      ; po co komu linker?
    dd 1024   ; tyyle miejsca na kod
    dd 1024   ; tyyle miejsca na dane
    dd 0      ; wiem co robię (ta, heh), nie potrzebuję niezainicjalizowanego miejsca
    dd 1024   ; tu się wchodzi do programu
    dd 1024   ; zaskakująco, kod się zaczyna na początku programu

HEADER_OPTIONAL: ; niby Windowsowe, ale UEFI też chce
    dq 0x100000 ; tu się wchodzi
    dd 0x1024   ; ustawienie segmentu w pliku i tak, 0x z przodu
    dd 0x1024   ; ustawienie pliku
    dw 0      ; nie jestem wybredny
    dw 0      ; nadal nie jestem wybredny
    dw 0      ; wersja tego pliku (duża)
    dw 0      ; wersja pliku (mała)
    dw 2      ; wersja OS (duża)
    dw 0      ; wersja OS (mała)
    dd 0      ; 0 bo tak
    dd 3072   ; 3KB ta przyjemność waży
    dd 1024   ; z czego tyle sama głowa
    dd 0      ; suma kontrolna?
    dw 0xa    ; UEFI tego potrzebuje
    dw 0      ; to nie DLL

    dq 0x8000 ; o tyle stosu chcę
    dq 0x8000 ; i chcę go natychmiast
    dq 0x8000 ; i tyle sterty, w razie czego
    dq 0      ; obym nie musiał jej użyć
    dd 0      ; 0 bo tak
    dd 0      ; nie robimy słownika

HEADER_END:
SECTIONS:
.1: ; .text
    dq ".text"
    dd 1024 ; rozmiar wirtualny
    dd 1024 ; tu się niby wchodzi
    dd 1024 ; rozmiar prawdziwy
    dd 1024 ; tu się naprawdę wchodzi
    dd 0    ; niczego nie przesuwaj
    dd 0    ; ani nie numeruj
    dw 0    ; naprawdę
    dw 0    ; nie trzeba
    dd 0x60000020 ; rwx

.2:
    dq ".data"
    dd 1024
    dd 2048 ; zaraz za kodem
    dd 1024
    dd 2048
    dd 0
    dd 0
    dw 0
    dw 0 
    dd 0xc0000040 ; rw, zainicjalizowane dane

times 1024 - ($ - $$) db 0

; nareszcie jakiś kod
segment .text follows=.header

    EFI_SUCCESS equ 0

    OFFSET_CONSOLE_OUTPUT_STRING equ 8
    OFFSET_TABLE_OUTPUT_CONSOLE equ 64
    OFFSET_TABLE_ERROR_CONSOLE equ 80
    OFFSET_TABLE_RUNTIME_SERVICES equ 88
    OFFSET_TABLE_BOOT_SERVICES equ 96
    OFFSET_BOOT_EXIT_PROGRAM equ 216
    OFFSET_BOOT_STALL equ 248

    waitTime equ 1000000

start:
    sub rsp, 6*8+8 ; ? znormalizuj stos
    ; przyszła nam SYSTEM_TABLE, przeczytaj ją
    mov [EFI_HANDLE], rcx
    mov [EFI_SYSTEM_TABLE], rdx
    mov [EFI_RETURN], rsp

    ; przygotuj usługi
    add rdx, OFFSET_TABLE_BOOT_SERVICES
    mov rcx, [rdx]
    mov [BOOT_SERVICES], rcx
    add rcx, OFFSET_BOOT_EXIT_PROGRAM ; funkcja do wyjazdu
    mov rdx, [rcx]
    mov [BOOT_SERVICES_EXIT], rdx
    mov rcx, [BOOT_SERVICES]
    add rcx, OFFSET_BOOT_STALL ; czekaj
    mov rdx, [rcx]
    mov [BOOT_SERVICES_STALL], rdx

    ; konsola
    mov rdx, [EFI_SYSTEM_TABLE]
    add rdx, OFFSET_TABLE_ERROR_CONSOLE ; w razie wyłożenia się na pysk
    mov rcx, [rdx]
    mov [CONERR], rcx
    add rcx, OFFSET_CONSOLE_OUTPUT_STRING
    mov rdx, [rcx]
    mov [CONERR_PRINT_STRING], rdx

    mov rdx, [EFI_SYSTEM_TABLE]
   add rdx, OFFSET_TABLE_OUTPUT_CONSOLE 
   mov rcx, [rdx]
   mov [CONOUT], rcx
   add rcx, OFFSET_CONSOLE_OUTPUT_STRING ; normalne wyjście
   mov rdx, [rcx]
   mov [CONOUT_PRINT_STRING], rdx

   mov rdx, [EFI_SYSTEM_TABLE]
   add rdx, OFFSET_TABLE_RUNTIME_SERVICES
   mov rcx, [rdx]
   mov [RUNTIME_SERVICES], rcx

  
   xor rcx, rcx
   xor rdx, rdx
   xor r8, r8

   ; drukuj stringa
   mov rcx, [CONOUT]
   lea rdx, [waitString]
   call [CONOUT_PRINT_STRING]

   ; czekaj
   mov rcx, waitTime
   call [BOOT_SERVICES_STALL]

   ; znowu drukuj stringa
   mov rcx, [CONOUT]
   lea rdx, [hello]
   call [CONOUT_PRINT_STRING]

   ; wracaj do UEFA
   mov rcx, [EFI_HANDLE]
   mov rdx, EFI_SUCCESS
   mov r8, 1
   call [BOOT_SERVICES_EXIT]

   ret

times 1024 - ($-$$) db 0


section .data follows=.text
dataStart:

   EFI_HANDLE dq 0
   EFI_SYSTEM_TABLE dq 0
   EFI_RETURN dq 0


   BOOT_SERVICES dq 0
   BOOT_SERVICES_EXIT dq 0 
   BOOT_SERVICES_STALL dq 0
   CONERR dq 0
   CONERR_PRINT_STRING dq 0
   CONOUT dq 0
   CONOUT_PRINT_STRING dq 0
   RUNTIME_SERVICES dq 0
   
   waitString db __utf16__ `Czekaj se\r\n\0`
   hello db __utf16__ "LEGIA TO CHUJE A LECH MISTRZ POLSKI ĄĘŚĆCHUJ\r\n\0"

times 1024 - ($-$$) db 0 