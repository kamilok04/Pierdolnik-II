cmake_minimum_required(VERSION 3.10)


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

set(CMAKE_ASM_NASM_LINK_EXECUTABLE "ld <CMAKE_ASM_NASM_LINK_FLAGS> <LINK_FLAGS> <OBJECTS>  -o <TARGET> <LINK_LIBRARIES>")
set(CMAKE_SYSTEM_NAME PierdolnikOS)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

MACRO_ENSURE_SYSROOT(${CMAKE_SOURCE_DIR}/sysroot)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set_property(CACHE CMAKE_INSTALL_PREFIX PROPERTY VALUE ${CMAKE_SYSROOT})
endif()

set(TOOLCHAIN_PREFIX "i686-elf-")
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER) # NIE szukaj rzeczy w hoście
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CMAKE_C_COMPILER ${PREFIX}gcc)
set(CMAKE_C_FLAGS "-o2 -g --sysroot=${SYSROOT} -ffreestanding -nostdlib -Wall -Wextra")
set(CMAKE_ASM_NASM_COMPILER nasm)
set(CMAKE_ASM_NASM_FILE_EXTENSIONS .asm)
set(CMAKE_ASM_NASM_FLAGS "-g -Fdwarf")
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
COMMAND "nasm" "${KERNEL_ROOT}/boot.asm" "-fbin" "-o ${CMAKE_SYSROOT}/boot/boot.bin" VERBATIM
)

add_executable(kernel
    ${KERNEL_ROOT}/kernel.asm
)

install(TARGETS kernel DESTINATION ${CMAKE_SYSROOT}/kernel)
add_custom_target(compile_system ALL DEPENDS boot kernel
# kernel musi być na dyskietce :)
COMMAND "dd" "if=/dev/zero" "of=${CMAKE_SYSROOT}/boot/boot.img" "bs=1024" "count=1440"  # 1.44MiB - zwykła dyskietka, jak standard El Torrito wymaga
                                                                                        # 1200KiB i 2880MiB też są dopuszczalne
                                                                                        # TODO: popatrzeć na no-emul-boot
COMMAND "dd" "if=${CMAKE_SYSROOT}/boot/boot.bin" "of=${CMAKE_SYSROOT}/boot/boot.img" "seek=0" "count=1" "conv=notrunc"
COMMAND "genisoimage" "-V" "'WPIERDOL'" "-input-charset" "iso8859-1" "-o" "../wpierdol.iso" "-b" "boot/boot.img" "-hide" "boot/boot.img" "${CMAKE_SYSROOT}" 
# COMMAND "genisoimage" "-V" "'WPIERDOL'" "-no-emul-boot" "-input-charset" "iso8859-1" "-o" "../wpierdol.iso" "-b" "boot/boot.img" "-hide" "boot/boot.img" "${CMAKE_SYSROOT}" 
)



