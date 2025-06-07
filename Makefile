AS = nasm
CC = gcc
LD = ld

ASFLAGS = -felf32
CFLAGS = -m32 -ffreestanding -O2 -Wall -Wextra -fno-stack-protector -nostdlib
LDFLAGS = -melf_i386 -T kernel.ld

# Choix du kernel
KERNEL_SRC = kernel/kernel_simple.c  # Par défaut
ifdef FILESYSTEM
KERNEL_SRC = kernel/kernel.c  # Avec système de fichiers
endif

all: HybridOS.iso

boot.o: kernel/boot_fs.asm
	$(AS) $(ASFLAGS) kernel/boot_fs.asm -o boot.o

kernel.o: $(KERNEL_SRC)
	$(CC) $(CFLAGS) -c $(KERNEL_SRC) -o kernel.o

kernel.elf: boot.o kernel.o
	$(LD) $(LDFLAGS) boot.o kernel.o -o kernel.elf

HybridOS.iso: kernel.elf
	@mkdir -p iso/boot/grub
	@cp kernel.elf iso/boot/
	@echo 'set timeout=0' > iso/boot/grub/grub.cfg
	@echo 'menuentry "HybridOS FileSystem Edition" {' >> iso/boot/grub/grub.cfg
	@echo '    multiboot /boot/kernel.elf' >> iso/boot/grub/grub.cfg
	@echo '    boot' >> iso/boot/grub/grub.cfg
	@echo '}' >> iso/boot/grub/grub.cfg
	@grub-mkrescue -o HybridOS.iso iso 2>/dev/null

clean:
	rm -f *.o *.elf *.iso
	rm -rf iso

run: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 128M -display sdl

# Compile avec système de fichiers
fs: clean
	make FILESYSTEM=1

# Revenir à l'ancienne version
simple: clean
	cp kernel/kernel_simple.c kernel/kernel.c
	make

.PHONY: all clean run fs simple
