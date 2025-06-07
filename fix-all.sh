#!/bin/bash
echo "🔧 Correction totale de HybridOS..."

# Créer kernel.c sans headers standards
cat > kernel/kernel.c << 'EOF'
// Types définis manuellement
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long size_t;

static uint16_t* const VGA_MEMORY = (uint16_t*)0xB8000;

static inline uint16_t vga_entry(char c, uint8_t color) {
    return (uint16_t)c | (uint16_t)color << 8;
}

void kernel_main(void) {
    // Message simple directement en mémoire vidéo
    const char* msg = "HybridOS Started Successfully!";
    uint8_t color = 0x0A; // Vert clair sur noir
    
    for (int i = 0; msg[i] != '\0'; i++) {
        VGA_MEMORY[i] = vga_entry(msg[i], color);
    }
    
    // Message Windows/Linux
    const char* msg2 = "Windows + Linux = HybridOS";
    for (int i = 0; msg2[i] != '\0'; i++) {
        VGA_MEMORY[80 + i] = vga_entry(msg2[i], 0x0B);
    }
    
    while(1) __asm__("hlt");
}
EOF

# Créer Makefile simple
cat > Makefile << 'EOF'
all: HybridOS.iso

boot.o: kernel/boot.asm
	nasm -felf32 kernel/boot.asm -o boot.o

kernel.o: kernel/kernel.c  
	gcc -m32 -ffreestanding -fno-stack-protector -c kernel/kernel.c -o kernel.o

kernel.elf: boot.o kernel.o
	ld -melf_i386 -T kernel.ld boot.o kernel.o -o kernel.elf

HybridOS.iso: kernel.elf
	mkdir -p iso/boot/grub
	cp kernel.elf iso/boot/
	echo 'menuentry "HybridOS" { multiboot /boot/kernel.elf }' > iso/boot/grub/grub.cfg
	grub-mkrescue -o HybridOS.iso iso 2>/dev/null

clean:
	rm -rf *.o *.elf *.iso iso

run: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso
EOF

echo "🔨 Compilation..."
make clean
make

if [ -f "HybridOS.iso" ]; then
    echo "✅ Succès! ISO créée: $(ls -lh HybridOS.iso | awk '{print $5}')"
    echo "🚀 Lance avec: make run"
else
    echo "❌ Erreur!"
fi
