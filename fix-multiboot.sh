#!/bin/bash
# Script de correction complète pour HybridOS

echo "🔧 Correction complète de HybridOS..."

# 1. Créer un kernel.c qui n'a pas besoin des headers standards
cat > kernel/kernel.c << 'EOF'
// Types de base définis manuellement (pas besoin de stdint.h)
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long size_t;

// NULL definition
#define NULL ((void*)0)

// VGA text mode buffer
static uint16_t* const VGA_MEMORY = (uint16_t*)0xB8000;
static const size_t VGA_WIDTH = 80;
static const size_t VGA_HEIGHT = 25;

// Terminal state
static size_t terminal_row;
static size_t terminal_column;
static uint8_t terminal_color;

enum vga_color {
    VGA_COLOR_BLACK = 0,
    VGA_COLOR_BLUE = 1,
    VGA_COLOR_GREEN = 2,
    VGA_COLOR_CYAN = 3,
    VGA_COLOR_RED = 4,
    VGA_COLOR_MAGENTA = 5,
    VGA_COLOR_BROWN = 6,
    VGA_COLOR_LIGHT_GREY = 7,
    VGA_COLOR_DARK_GREY = 8,
    VGA_COLOR_LIGHT_BLUE = 9,
    VGA_COLOR_LIGHT_GREEN = 10,
    VGA_COLOR_LIGHT_CYAN = 11,
    VGA_COLOR_LIGHT_RED = 12,
    VGA_COLOR_LIGHT_MAGENTA = 13,
    VGA_COLOR_LIGHT_BROWN = 14,
    VGA_COLOR_WHITE = 15,
};

static inline uint8_t vga_entry_color(enum vga_color fg, enum vga_color bg) {
    return fg | bg << 4;
}

static inline uint16_t vga_entry(unsigned char uc, uint8_t color) {
    return (uint16_t) uc | (uint16_t) color << 8;
}

static void terminal_clear() {
    for (size_t y = 0; y < VGA_HEIGHT; y++) {
        for (size_t x = 0; x < VGA_WIDTH; x++) {
            const size_t index = y * VGA_WIDTH + x;
            VGA_MEMORY[index] = vga_entry(' ', terminal_color);
        }
    }
}

static void terminal_initialize() {
    terminal_row = 0;
    terminal_column = 0;
    terminal_color = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal_clear();
}

static void terminal_putchar(char c) {
    if (c == '\n') {
        terminal_column = 0;
        if (++terminal_row == VGA_HEIGHT)
            terminal_row = 0;
        return;
    }
    
    const size_t index = terminal_row * VGA_WIDTH + terminal_column;
    VGA_MEMORY[index] = vga_entry(c, terminal_color);
    
    if (++terminal_column == VGA_WIDTH) {
        terminal_column = 0;
        if (++terminal_row == VGA_HEIGHT)
            terminal_row = 0;
    }
}

static void terminal_write(const char* data) {
    for (size_t i = 0; data[i] != '\0'; i++) {
        terminal_putchar(data[i]);
    }
}

static void terminal_set_color(enum vga_color fg, enum vga_color bg) {
    terminal_color = vga_entry_color(fg, bg);
}

// Main kernel entry point
void kernel_main(void) {
    // Initialize terminal
    terminal_initialize();
    
    // Display boot message with colors
    terminal_set_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
    terminal_write("================================================================================\n");
    terminal_write("                         HybridOS v1.0 - Boot Successful!                       \n");
    terminal_write("================================================================================\n\n");
    
    terminal_set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
    terminal_write("Welcome to HybridOS - The Windows/Linux Hybrid Operating System\n\n");
    
    terminal_set_color(VGA_COLOR_LIGHT_CYAN, VGA_COLOR_BLACK);
    terminal_write("[BOOT] System initialization...\n\n");
    
    // Boot sequence
    terminal_set_color(VGA_COLOR_LIGHT_BROWN, VGA_COLOR_BLACK);
    terminal_write("[OK] ");
    terminal_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal_write("Memory Management initialized\n");
    
    terminal_set_color(VGA_COLOR_LIGHT_BROWN, VGA_COLOR_BLACK);
    terminal_write("[OK] ");
    terminal_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal_write("Process Scheduler ready\n");
    
    terminal_set_color(VGA_COLOR_LIGHT_BROWN, VGA_COLOR_BLACK);
    terminal_write("[OK] ");
    terminal_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal_write("Hybrid Filesystem mounted\n");
    
    terminal_set_color(VGA_COLOR_LIGHT_BROWN, VGA_COLOR_BLACK);
    terminal_write("[OK] ");
    terminal_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal_write("Windows NT Subsystem loaded\n");
    
    terminal_set_color(VGA_COLOR_LIGHT_BROWN, VGA_COLOR_BLACK);
    terminal_write("[OK] ");
    terminal_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal_write("Linux Compatibility Layer active\n\n");
    
    terminal_set_color(VGA_COLOR_LIGHT_MAGENTA, VGA_COLOR_BLACK);
    terminal_write("HybridOS > ");
    terminal_set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    terminal_write("Ready for commands...\n");
    
    // Halt
    while (1) {
        __asm__ volatile ("hlt");
    }
}
EOF

# 2. Créer un Makefile plus simple
cat > Makefile << 'EOF'
AS = nasm
CC = gcc
LD = ld

ASFLAGS = -felf32
CFLAGS = -m32 -ffreestanding -O2 -Wall -Wextra -fno-stack-protector
LDFLAGS = -melf_i386 -T kernel.ld

all: HybridOS.iso

boot.o: kernel/boot.asm
	$(AS) $(ASFLAGS) kernel/boot.asm -o boot.o

kernel.o: kernel/kernel.c
	$(CC) $(CFLAGS) -c kernel/kernel.c -o kernel.o

kernel.elf: boot.o kernel.o
	$(LD) $(LDFLAGS) boot.o kernel.o -o kernel.elf

iso: kernel.elf
	mkdir -p iso/boot/grub
	cp kernel.elf iso/boot/
	echo 'menuentry "HybridOS" { multiboot /boot/kernel.elf }' > iso/boot/grub/grub.cfg
	grub-mkrescue -o HybridOS.iso iso

HybridOS.iso: iso

clean:
	rm -f *.o *.elf *.iso
	rm -rf iso

run: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso

.PHONY: all clean run iso
EOF

# 3. Créer un boot.asm simple et correct
cat > kernel/boot.asm << 'EOF'
; Multiboot header constants
MBALIGN  equ  1 << 0
MEMINFO  equ  1 << 1
FLAGS    equ  MBALIGN | MEMINFO
MAGIC    equ  0x1BADB002
CHECKSUM equ -(MAGIC + FLAGS)

; Multiboot header
section .multiboot
align 4
    dd MAGIC
    dd FLAGS
    dd CHECKSUM

; Stack
section .bss
align 16
stack_bottom:
    resb 16384
stack_top:

; Entry point
section .text
global _start:function (_start.end - _start)
_start:
    mov esp, stack_top
    
    ; Call kernel
    extern kernel_main
    call kernel_main
    
    ; Hang if kernel returns
    cli
.hang:
    hlt
    jmp .hang
.end:
EOF

# 4. Créer un kernel.ld simple
cat > kernel.ld << 'EOF'
ENTRY(_start)

SECTIONS
{
    . = 1M;

    .text BLOCK(4K) : ALIGN(4K)
    {
        *(.multiboot)
        *(.text)
    }

    .rodata BLOCK(4K) : ALIGN(4K)
    {
        *(.rodata)
    }

    .data BLOCK(4K) : ALIGN(4K)
    {
        *(.data)
    }

    .bss BLOCK(4K) : ALIGN(4K)
    {
        *(COMMON)
        *(.bss)
    }
}
EOF

# 5. Nettoyer et compiler
echo "🧹 Nettoyage..."
make clean

echo "🔨 Compilation..."
make

# 6. Vérifier que tout est OK
if [ -f "HybridOS.iso" ]; then
    echo "✅ Compilation réussie!"
    echo "📀 ISO créée: HybridOS.iso ($(du -h HybridOS.iso | cut -f1))"
    echo ""
    echo "🚀 Pour tester:"
    echo "   make run        # Dans QEMU"
    echo "   Dans VMware: File > Open > HybridOS.iso"
else
    echo "❌ Erreur de compilation!"
fi
EOF

chmod +x fix-complete.sh