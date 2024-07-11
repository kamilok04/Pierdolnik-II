cmake_minimum_required(VERSION 3.8)


# MAKRA ======================================================

MACRO(MACRO_ENSURE_OUT_OF_SOURCE_BUILD MSG)
     STRING(COMPARE EQUAL "${CMAKE_SOURCE_DIR}"
     "${CMAKE_BINARY_DIR}" insource)
     GET_FILENAME_COMPONENT(PARENTDIR ${CMAKE_SOURCE_DIR} PATH)
     STRING(COMPARE EQUAL "${CMAKE_SOURCE_DIR}"
     "${PARENTDIR}" insourcesubdir)
    IF(insource OR insourcesubdir)
        MESSAGE(FATAL_ERROR "${MSG}")
    ENDIF(insource OR insourcesubdir)
ENDMACRO(MACRO_ENSURE_OUT_OF_SOURCE_BUILD)

MACRO(MACRO_ENSURE_SYSROOT DIR)
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${DIR}
    )
    set(CMAKE_SYSROOT ${DIR})
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SYSROOT}/boot
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SYSROOT}/kernel
    )
ENDMACRO(MACRO_ENSURE_SYSROOT)
# ============================================================

# wsparcie dla starszych CMake
# o co chodzi? wersje <3.30 mają buga
# traktują NASM jak linker, którym oczywiście nie jest
if($<VERSION_LESS:${VERSION},"3.30">)
set(CMAKE_ASM_NASM_SOURCE_FILE_EXTENSIONS
${CMAKE_ASM_NASM_SOURCE_FILE_EXTENSIONS} s S)
endif()

set(CMAKE_ASM_NASM_LINK_EXECUTABLE 
"ld <CMAKE_ASM_NASM_LINK_FLAGS>\
<LINK_FLAGS> <OBJECTS> \
-o <TARGET> <LINK_LIBRARIES>")
set(CMAKE_SYSTEM_NAME PierdolnikOS)
set(CMAKE_SYSTEM_PROCESSOR AMD64) # bardzo daleko w przyszłości todo: inne architektury?
set(PROCESSOR_MODEL "2137") # Sposoby budowania mogą się zmienić w zależności od tego tu

MACRO_ENSURE_SYSROOT(${CMAKE_CURRENT_SOURCE_DIR}/sysroot)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set_property(CACHE CMAKE_INSTALL_PREFIX PROPERTY VALUE ${CMAKE_SYSROOT})
endif()

set(TOOLCHAIN_PREFIX "i686-elf-")
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER) # NIE szukaj rzeczy w hoście
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CMAKE_C_COMPILER ${PREFIX}gcc)
#set(CMAKE_C_FLAGS "-o2 -g --sysroot=${SYSROOT} -ffreestanding -nostdlib -Wall -Wextra")
set(CMAKE_ASM_NASM_COMPILER nasm)
set(CMAKE_ASM_NASM_FILE_EXTENSIONS .asm)
#set(CMAKE_ASM_NASM_FLAGS "-g -Fdwarf")
set(CMAKE_ASM_NASM_OBJECT_FORMAT elf64)




set(CMAKE_HOST "i686-elf")
string(REGEX MATCH "i[0-9]86" HOSTARCH ${CMAKE_HOST})
if(NOT HOSTARCH MATCHES "$^")
set(HOSTARCH i386)
else()
string(REGEX MATCH "[0-9a-zA-Z]+" HOSTARCH ${CMAKE_HOST})
endif()

project(PierdolnikOS LANGUAGES ASM_NASM)

message("Kompiluję pod ${HOSTARCH}")

MACRO_ENSURE_OUT_OF_SOURCE_BUILD(
    "${CMAKE_PROJECT_NAME} wymaga zbudowania w folderze niezawierającym źródeł. Skonsultuj się z dokumentacją."
)




set(KERNEL_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/kernel/arch/${HOSTARCH})

# bootloader wymaga specjalnego traktowania, bo
# 1. potrzebuję pliku .bin
# 2. NIE WOLNO tego wsadzić do linkera
# 3. powinno się użyć install(), ale bootloader jest oczywiście Specjalny™
add_custom_target(boot
COMMAND ${CMAKE_ASM_NASM_COMPILER} 
"${KERNEL_ROOT}/boot.asm" 
"-i${KERNEL_ROOT}/"
"-fbin"
"-o${CMAKE_SYSROOT}/boot/boot.bin" 
"$<$<CONFIG:DEBUG>:-llistings/boot.lst>"
VERBATIM
COMMAND ${CMAKE_ASM_NASM_COMPILER} 
"${KERNEL_ROOT}/boot2.asm" 
"-i${KERNEL_ROOT}/"
"-fbin"
"-o${CMAKE_SYSROOT}/boot/bot2.bin" 
"$<$<CONFIG:DEBUG>:-llistings/boot2.lst>"
VERBATIM
)


add_executable(kernel
    ${KERNEL_ROOT}/kernel.asm
)
set_target_properties(kernel PROPERTIES
RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SYSROOT}/kernel)

if(${PROCESSOR_MODEL} EQUAL "8086") # wsparcie dla ANTYKÓW
    add_custom_target(compile_system ALL DEPENDS boot kernel
    # kernel musi być na dyskietce :)
    COMMAND "dd" "if=/dev/zero" "of=${CMAKE_SYSROOT}/boot/boot.img" "bs=1024" "count=1440"  # 1.44MiB - zwykła dyskietka, jak standard El Torrito wymaga
                                                                                        # 1200KiB i 2880MiB też są dopuszczalne
                                                                                        # ~TODO: popatrzeć na no-emul-boot
    COMMAND "dd" "if=${CMAKE_SYSROOT}/boot/boot.bin" "of=${CMAKE_SYSROOT}/boot/boot.img" "seek=0" "count=1" "conv=notrunc"
    COMMAND "xorriso" "-as" "mkisofs" "-V" "'WPIERDOL'" "-input-charset" "iso8859-1" "-o" "../wpierdol.iso" "-b" "boot/boot.img" "-hide" "boot/boot.img" "${CMAKE_SYSROOT}" 
) 
else() # tu idzie wszystko nowsze niż 1982
add_custom_target(compile_system ALL DEPENDS boot kernel 
COMMAND "xorriso"
"-as" "mkisofs" 
"-input-charset" "iso8859-1"
"-R" # włącz uniksopodobne nazwy plików + atrybuty dostępu
"-iso-level" "3" # zezwól na duże pliki
"-V" "'WPIERDOL'" 
#"-U" # nagnij specyfikację i rozszerz zestaw znaków nazw plików
"-no-emul-boot" # zrywamy z antycznym sposobem, czyli emulacją dyskietki (Pierdolnik v1)
"-boot-load-size" "4" # wymagane przez -no-emul-boot
"-b" "boot/boot.bin" # plik rozruchowy
"-G" "${CMAKE_SYSROOT}/boot/boot.bin" # skopiuj go na początek CD, gdyby z jakiegoś powodu BIOS uznał płytę za dysk twardy
"-hide" "boot/boot.bin" # ukryj plik rozruchowy w spisie katalogów
"-o" "../wpierdol.iso" 
"${CMAKE_SYSROOT}" 
)
endif()

add_custom_target(run_system DEPENDS compile_system
COMMAND "killall" "qemu-system-i386" "||" "true"    # o co chodzi z tym >/dev/null?
                                                        # killall się sypie, jeśli żadnej maszyny nie ma
                                                        # a to zamiata błąd pod dywan
                                                        # efekt uboczny: wszystkie inne (być może bez związku) maszyny też umrą
COMMAND "qemu-system-i386" 
"-cdrom" "${CMAKE_SYSROOT}/../wpierdol.iso" "-daemonize"
"$<$<CONFIG:DEBUG>:-s>" # otwórz port 1234 dla debuggera
"$<$<CONFIG:DEBUG>:-S>" # czekaj na zezwolenie od debuggera, zanim zaczniesz działać
)

