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

; konwencja: za blokami opisanymi
; - koniec -
; można stawiać cokolwiek
; Pozostałych bloków bym nie ruszał
; x86, w odróżnieniu od np. C, 
; używa mechaniki "spadania" między funkcjami
; (IP leci do przodu i tyle)
; i możesz sobie sporo zepsuć, tasując rzeczy

; tu się zaczyna właściwy kod
start:

    ; przygotuj rejestry
    cli ; przerwanie w tym miejscu spowodowałoby burdel, wyłącz je
    mov bp, 0x7c00
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, bp
    sti

    call loading

    ; druga runda żyje na dysku
    ; dane dostępowe są w szesnastym sektorze
    ; xorriso już tam wszystkie potrzebne rzeczy wpisał :)
    ; uwaga: LBA zaczynają indeksowanie od 1

    ; wczytaj drugą rundę
    ; ścieżka: /boot/boot2.bin
    ; upewnij się, że BIOS potrafi w LBA
    clc
    mov ah, 0x41
    mov bx, 0x55aa
    int 0x13
    jc short .CHSFallback ; jeśli przeniesienie jest, to LBA nie zadziała

    call LBALoad
    jmp short .loadSuccess
    ; - koniec -

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
    ; (aha)^5
    ; płyty kompletnie nie wspierają CHS
    ; to jest wsm tylko dla starszego podejścia (emulacja dyskietki)

    ; *BIOS to nieustandaryzowany syf i każdy producent ma swoje zasady
    ; --- koniec narzekania na CHS ---

    ; instrukcja obsługi zaleca co najmniej 3 próby, bo dyskietka może się nie rozpędzić w wymaganym czasie
    ; i to jest normalne
    call CHSAttempt
    jnc short .loadSuccess
    call resetDrive
    call CHSAttempt
    jnc short .loadSuccess
    call resetDrive
    call CHSAttempt
    jnc short .loadSuccess
    call diskError

    ; - koniec -

.wrongSector:
    inc dword[diskPacket.sector]
    call LBALoad

.loadSuccess:

    ; upewnij się, że mamy wczytaną PVD
    cmp byte[0x1000], 1
    jne short .wrongSector


    ; mamy - zlokalizuj tablicę folderów
    mov eax, dword[0x108c]
    mov dword[diskPacket.sector], eax
    call LBALoad

    ; mamy tablicę folderów
    ; znajdź taki o nazwie 'BOOT'
    mov di, 0x1000
.readPathTableEntry:
    ; pierwsze kryterium: długość nazwy == 4

    movzx cx, byte[di]
    cmp cx, 4
    jne .wrongPath

    ; drugie kryterium: nazwa to 'BOOT'
    add di, 8

    ; tak, w trybie rzeczywistym działa CMP R/M32, IMM32
    ; sam byłem tym zdziwiony
    cmp dword[di], "BOOT"
    
    jne .wrongPathName

    ; znalazłem folder, co wczytać?
    mov eax, dword[di - 8 + 2] ; cofnij do początku wpisu i przewiń 2 bity w przód
    mov dword[diskPacket.sector], eax
    call LBALoad

    

    ; jestem w poprawnym folderze, gdzie ten plik?
    ; szukamy pliku boot2.bin
    ; w pliku wygląda tak:  BOT2.BIN;1
    ; pierwsze kryterium: znaleźć ";1"
    ; dlaczego niby BOT zamiast BOOT?
    ; z lenistwa, za parę linijek zobaczysz :)

    mov di, 0x1000
    mov cx, 0x800 ; nie wyjedź za sektor
    mov al, ';'
    cld ; szukaj w dobrą stronę :)

.findASemicolon:
    repne scasb
    test cx, cx
    jz short .noStage2 ; ostatnia możliwa wartość średnika to 0x17ff => CX = 1

    ; czy za tym stoi jedynka? 
    ; przypominajka: REPxx zostawiają wartość (E/R)DI, która *byłaby sprawdzana następna*,
    ; czyli "o 1 za daleko"
    cmp byte[di], '1' ; nie di+1
    jne short .findASemicolon
    
    ; trzecie kryterium: czy to się nazywa "BOT2.BIN"?
    cmp dword[di-5], ".BIN"
    jne short .findASemicolon
    cmp dword[di-9], "BOT2" ; BOOT2.BIN by się nie zmieścił :)
    jne short .findASemicolon

    ; mamy plik! Ładuj

    ; ile sektorów, mocium panie?
    mov eax, dword[di-0x20] ; ISO 9660 pozdrawia <3
    shr eax, 11 ; podziel przez 0x800 (rozmiar sektora)
    inc eax
    mov [diskPacket.sectorsCount], ax

    ; od którego sektora zacząć?
    mov eax, dword[di-0x28]
    mov dword[diskPacket.sector], eax

    call LBALoad

    ; gotowe, spadam stąd!
    
    jmp 0:0x1000
    


.wrongPath:
    cmp di, 0x1800 ; koniec sektora
    jge .noStage2
    test cx, cx
    jz .noStage2    ; puste wpisy, koniec listy
    add di, 9       ; tyle zajmuje struktura
.wrongPathName:
    add di, cx 
    and di, 0xfffe ; uwzględnij padding
    ; próbuj dalej
    jmp short .readPathTableEntry

.noStage2:
    call loading
    call loading
    call diskError






; resetuje dysk
; przyjmuje: nic
; zwraca: kod błędu w AH, ustawia przeniesienie
; zaśmieca: AX
resetDrive:
    mov ah, 0
    int 0x13
    test ah, ah
    jc .failed
    ret
.failed:
    call diskError

; czyta sektor z dysku z użyciem LBA
; próbuje trzy razy i jeśli się nie uda, kończy tę imprezę
; przyjmuje: nic
; zwraca: kod błędu w AH, ustawia przeniesienie
; zaśmieca: AH, CX
LBALoad:
    mov cx, 3
.tryRead:
    mov si, diskPacket
    mov ah, 0x42
    int 0x13
    jnc .bye
    test cx, cx
    jz .failed
    call resetDrive
    dec cx
    jmp .tryRead
.failed:
    call diskError
.bye:
    ret

; drukuje jeden znak na ekranie
; przyjmuje: AL - znak do wyplucia
; zwraca: nic
; zaśmieca: BH
; może zaśmiecić BP, jeśli BIOS jest robiony po taniości
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

; materiały, które napotkałem, zalecają tu dyrektywę
; align 32
; ale z nią zachodzi kataklizm i żaden odczyt nie działa
; a BIOS zgłasza próbę odczytu >128 sektorów
align 2
diskPacket:
                db 0x10   ; rozmiar struktury
                db 0      ; tu musi być 0
.sectorsCount:  dw 1      ; zamawiam 1 sektor
                dd 0x1000 ; adres docelowy; to musi zaczynać się na parzystym bicie
.sector:        dq 16     ; numer LBA

times 2048 - ($ - $$) db 0
dw 0xaa55