[org 0x7c00]

segment .text
global start
; po namyśle dotarłem do wniosku
; że zamiast planowanego FAT12/16
; spróbuję użyć exFAT
; po dwóch namysłach postanowiłem, że spróbuję czegoś innego
; to będzie dystrybucja LiveCD
; system plików: ISO 9660 + Rock Ridge
; problem i to spory: nie ma możliwości zapisu, jeśli rozruch nie jest z CD-RW/DVD±RW/DVD-RAM
; na razie będzie ramdisk, potem coś się wymyśli

; tu się zaczyna właściwy kod
start:

; przygotuj rejestry
cli ; przerwanie w tym miejscu spowodowałoby burdel, wyłącz je
mov ax, cs
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00
sti

call loading

; druga runda żyje na dysku
; dane dostępowe są w szesnastym sektorze
; xorriso już tam wszystkie potrzebne rzeczy wpisał :)
; uwaga: LBA zaczynają indeksowanie od 1

; wczytaj drugą rundę
; upewnij się, że BIOS potrafi w LBA
clc
mov ah, 0x41
mov bx, 0x55aa
int 0x13
jc .CHSFallback ; jeśli przeniesienie jest, to LBA nie zadziała

mov cl, 3
.LBALoad:
mov si, diskPacket
mov ah, 0x42
int 0x13
jnc short .loadSuccess

; zdarzają się problemy z dyskiem, spróbuj ponownie
test cl, cl
jz .diskUnrecoverableFailure
dec cl
call resetDrive
jmp short .LBALoad

.diskUnrecoverableFailure:
call diskError
; - koniec -

.loadSuccess:
; jej!

mov si, 0x1000
call puts
call reboot


.CHSFallback:
; LBA 16 = CHS (0, 0, 16)

; --- narzekanie na CHS ---
; CHS indeksuje jeszcze lepiej!
; cylindry i głowice indeksuje się od 0
; sektory indeksuje się od 1 :)
; aha
; BIOS nie zna fizycznych parametrów dysku, więc tworzy sobie własne
; odczytuje się je z int 0x13/AH=8/DL=dysk jaki akurat masz, pewnie 0x80
; (aha)^2
; to nie działa z dyskietkami, w takim przypadku parametry trzeba zgadnąć :)
; (aha)^3 
; jeśli się zdarzy, że dysk jest sformatowany FATem, w tabeli systemu plików są dane geometrii CHS
; one na 99% są źle i rozwalą system, jeśli się nimi zainspirujesz :)
; (aha)^4
; możesz czytać z jednego cylindra naraz
; jeśli masz coś pofgramentowane między cylindrami, możesz zacząć płakać
; a jeśli spróbujesz to obejść, czytając po całym cylindrze naraz
; to też możesz płakać, limit to zazwyczaj* 128 :)

; *BIOS to nieustandaryzowany syf i każdy producent ma swoje zasady
; --- koniec narzekania na CHS ---


; skończyły mi się rejestry, do których mógłbym wcisnąć licznik
; pora na odrolowywanie zarolowanych rolek
call CHSAttempt
jnc short .loadSuccess
call resetDrive
call CHSAttempt
jnc short .loadSuccess
call resetDrive
call CHSAttempt
jnc short .loadSuccess
jmp short .diskUnrecoverableFailure

; nie powinno cię tu być!
call loading
call diskError



; resetuje dysk
; przyjmuje: nic
; zwraca: kod błędu w AH, ustawia przeniesienie
; zaśmieca: AL, DL
resetDrive:
    mov ah, 0
    int 0x13
    test ah, ah
    jc start.diskUnrecoverableFailure
    ret

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
ret

; jak tego antyku użyć?
; AH = 2
; AL = liczba zamawianych sektorów
; CH = zamawiany cylinder & 0xff
; CL = startowy sektor | ((4 * cylinder) & 0xc0)
; DH = głowica (ale też 2 wysokie bity cylindra, bo tak)
; ES:BX = adres docelowy
; DL = numer dysku (dysk twardy zwykle 0x80, CD zwykle 0xe0)
; i oczywiście int 0x13 i módl się, żeby się nie rozleciało

CHSAttempt:
cld
mov ah, 2       ; odczyt, 3 to zapis
mov al, 10      ; zamawiam 1 sektor
mov ch, 0
mov cl, 10
mov dh, 0
mov bx, 0x1000  ; adres docelowy
                ; ES = 0, żeby nie oszaleć 
                ; gdybym tu chciał inną wartość, żeby jednak oszaleć:
                ; adres = 16 * ES + BX
int 0x13
ret

loadingprompt: db "Wczytywanie...", 13, 10, 0
loading:
mov si, loadingprompt
call puts
ret

rebootprompt: db 13, 10, "wciskaj co, aby reset", 0
reboot:
mov si, rebootprompt
call puts
xor ax, ax
int 0x16 ; czekaj na naciśnięcie czegoś
jmp 0xffff:0

diskerrorprompt: db "dysk w pizdu", 13, 10, 0
diskError:
mov si, diskerrorprompt
call puts
call reboot

diskPacket:
; materiały, które napotkałem, zalecają tu dyrektywę
; align 32
; ale z nią zachodzi kataklizm i żaden odczyt nie działa
; a BIOS zgłasza próbę odczytu >128 sektorów
align 2
db 0x10   ; rozmiar struktury
db 0      ; tu musi być 0
dw 1      ; zamawiam 1 sektor
dd 0x1000 ; adres docelowy; to musi zaczynać się na parzystym bicie
dq 16     ; numer LBA

times 2048 - ($ - $$) db 0
dw 0xaa55