[org 0x7c00]

segment .text
global start

jmp 0:start ; wygląda jak syf
nop         ; ale to standardowa praktyka
            ; chodzi o to, że niektóre BIOS ustawiają (standardowe)
            ; CS = 0, IP = 0x7c00
            ; a niektóre są specjalne i ustawiają
            ; CS = 0x7c00, IP = 0
            ; oczywiście na początku na jedno wychodzi, ale potem mogą się dziać fikołki
            ; typu "o, nie mogę ustawić IVT" bo przy CS = 0x7c00 pamięć 0x0-0x7bff jest nieosiągalna
            ; poza tym wersja z IP = 0 wymagałaby [ORG 0] jako pierwszej linijki

; to jest dobre miejsce na takie coś
; inne alternatywy:
; za startem (problem: ten kod będzie chciał się wykonać przy bootowaniu i i tak musisz go ominąć)
; na końcu pliku (problemy:
; - referencje mogą być niezdefiniowane
; - prawdopodobnie trzeba będzie wykonywać bliskie skoki po pliku zamiast krótkich
;   krótkie mają zasięg [-128; +127], a bliskie wymagają więcej bajtów (a mamy ich trochę mało :))
%include "./boot_common.inc"

; tu się zaczyna właściwy kod
start:

    ; przygotuj rejestry
    ; cli ; przerwanie w tym miejscu spowodowałoby burdel, wyłącz je
    mov bp, 0x7c00
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov SS, ax ; przesunięcie do SS wymusza skupienie uwagi
               ; i ogólnie zwiększa posłuszeństwo wobec rozkazów
    mov sp, bp
   ; sti
   ; jeeej, dwa bajty mniej

    REPORT loadingInfo

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
    ERROR diskErrorInfo

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
    mov dword[diskPacket.targetAddr], 0x1800 ; nie nadpisuj tabeli ścieżek
    call LBALoad

    

    ; jestem w poprawnym folderze, gdzie ten plik?
    ; szukamy pliku boot2.bin
    ; w pliku wygląda tak:  BOT2.BIN;1
    ; pierwsze kryterium: znaleźć ";1"
    ; dlaczego niby BOT zamiast BOOT?
    ; z lenistwa, za parę linijek zobaczysz :)

    mov di, 0x1800
    mov cx, 0x800 ; nie wyjedź za sektor
    mov al, ';'
    cld ; szukaj w dobrą stronę :)
.findASemicolon:
    repne scasb
    test cx, cx
    jz short .noStage2File ; ostatnia możliwa wartość średnika to 0x17ff => CX = 1

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
    jmp short .fileFound
 
.wrongPath:
    cmp di, 0x2000 ; koniec sektora
    jge .noStage2File
    test cx, cx
    jz .noStage2File    ; puste wpisy, koniec listy
    add di, 9       ; tyle zajmuje struktura
.wrongPathName:
    add di, cx 
    and di, 0xfffe ; uwzględnij padding
    ; próbuj dalej
    jmp short .readPathTableEntry
.fileFound:
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
    jmp 0:0x1800

.noStage2File:
    ERROR noStage2Info

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
    ERROR diskErrorInfo

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
    ERROR diskErrorInfo
.bye:
    ret


; ładuje dane z nośnika tak, jak zrobiłby twój dziadek
; przyjmuje:
; AH = 2
; AL = liczba zamawianych sektorów
; CH = zamawiany cylinder & 0xff
; CL = startowy sektor | ((4 * cylinder) & 0xc0)
; DH = głowica (ale też 2 wysokie bity cylindra, bo tak)
; ES:BX = adres docelowy
; DL = numer dysku (dysk twardy zwykle 0x80, CD zwykle 0xe0)
; zwraca: 
; smutek, gorycz, żal
; AH - kod nieuniknionego błędu
; AL - liczba pomyślnie przerzuconych sektorów
; zaśmieca: nic, bo wszystkiego używa
; flagi: CF jeśli błąd

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

; materiały, które napotkałem, zalecają tu dyrektywę
; align 32
; ale z nią zachodzi kataklizm i żaden odczyt nie działa
; a BIOS zgłasza próbę odczytu >128 sektorów
align 2
diskPacket:
                db 0x10   ; rozmiar struktury
                db 0      ; tu musi być 0
.sectorsCount:  dw 1      ; zamawiam 1 sektor
.targetAddr:    dd 0x1000 ; adres docelowy; to musi zaczynać się na parzystym bicie
.sector:        dq 16     ; numer LBA


times 510 - ($ - $$) db 0   ; domyślnie używam nie-emulowanego El Torrito, czyli mam 2KB na bootloader pierwszej fazy
                            ; wolałbym jednak, żeby z dyskietki też się dało tym uruchomić system
                            ; w razie czego
dw 0xaa55