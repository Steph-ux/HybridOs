AS = nasm
CC = gcc
LD = ld

ASFLAGS = -felf32
CFLAGS = -m32 -ffreestanding -O2 -Wall -Wextra -fno-stack-protector -nostdlib
LDFLAGS = -melf_i386 -T kernel.ld

# Versions disponibles
KERNEL_SRC = kernel/kernel.c  # Ultimate par défaut

all: HybridOS.iso

boot.o: kernel/boot.asm
	$(AS) $(ASFLAGS) kernel/boot.asm -o boot.o

kernel.o: $(KERNEL_SRC)
	$(CC) $(CFLAGS) -c $(KERNEL_SRC) -o kernel.o

kernel.elf: boot.o kernel.o
	$(LD) $(LDFLAGS) boot.o kernel.o -o kernel.elf

HybridOS.iso: kernel.elf
	@mkdir -p iso/boot/grub
	@cp kernel.elf iso/boot/
	@echo 'set timeout=0' > iso/boot/grub/grub.cfg
	@echo 'menuentry "HybridOS Ultimate v2.0" {' >> iso/boot/grub/grub.cfg
	@echo '    multiboot /boot/kernel.elf' >> iso/boot/grub/grub.cfg
	@echo '    boot' >> iso/boot/grub/grub.cfg
	@echo '}' >> iso/boot/grub/grub.cfg
	@grub-mkrescue -o HybridOS.iso iso 2>/dev/null

clean:
	rm -f *.o *.elf *.iso
	rm -rf iso

run: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 256M -display sdl

run-curses: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 256M -display curses

debug: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 256M -d int -no-reboot

.PHONY: all clean run run-curses debug
