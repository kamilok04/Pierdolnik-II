ASM := nasm
OUT := out
IMG_NAME := pierdolnik

boot: boot.asm
	mkdir -p $(OUT)
	$(ASM) -fbin $< -o $(OUT)/$@.o
	dd if=$(OUT)/$@.o bs=512 of=$(OUT)/$(IMG_NAME).bin

run: boot
	# to jest obiektywnie złe
	killall qemu-system-i386 || /bin/true
	if qemu-system-i386 -drive file=$(OUT)/$(IMG_NAME).bin,index=0,format=raw,media=disk -name PIWO -daemonize ; then \
		echo "połącz się z localhost::5900, żeby wiedzieć, co się dzieje"; \
	else \
		echo "Maszyna już działa, musisz ją najpierw uśmiercić"; \
	fi

all: run

clean:
	rm -r out/*