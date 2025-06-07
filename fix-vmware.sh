#!/bin/bash
# Fix pour le problème de boucle sur VMware

echo "🔧 Correction du problème de boucle VMware..."

# Créer un kernel plus simple sans IDT complexe
cat > kernel/kernel_simple.c << 'EOF'
// Types de base
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long size_t;
#define NULL ((void*)0)

// VGA
#define VGA_WIDTH 80
#define VGA_HEIGHT 25
static uint16_t* const VGA_MEMORY = (uint16_t*)0xB8000;

// Terminal state
static size_t term_row = 0;
static size_t term_col = 0;
static uint8_t term_color = 0x07;
static char input_buffer[256];
static int input_pos = 0;

// I/O
static inline void outb(uint16_t port, uint8_t val) {
    __asm__ volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    __asm__ volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

// String functions
size_t strlen(const char* str) {
    size_t len = 0;
    while (str[len]) len++;
    return len;
}

int strcmp(const char* s1, const char* s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++; s2++;
    }
    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

// VGA functions
static inline uint16_t vga_entry(char c, uint8_t color) {
    return (uint16_t)c | (uint16_t)color << 8;
}

void term_clear() {
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        VGA_MEMORY[i] = vga_entry(' ', term_color);
    }
    term_row = 0;
    term_col = 0;
}

void term_scroll() {
    for (int i = 0; i < VGA_WIDTH * (VGA_HEIGHT - 1); i++) {
        VGA_MEMORY[i] = VGA_MEMORY[i + VGA_WIDTH];
    }
    for (int i = VGA_WIDTH * (VGA_HEIGHT - 1); i < VGA_WIDTH * VGA_HEIGHT; i++) {
        VGA_MEMORY[i] = vga_entry(' ', term_color);
    }
    term_row = VGA_HEIGHT - 1;
}

void term_putchar(char c) {
    if (c == '\n') {
        term_col = 0;
        if (++term_row >= VGA_HEIGHT) term_scroll();
    } else if (c == '\b') {
        if (term_col > 0) {
            term_col--;
            VGA_MEMORY[term_row * VGA_WIDTH + term_col] = vga_entry(' ', term_color);
        }
    } else {
        VGA_MEMORY[term_row * VGA_WIDTH + term_col] = vga_entry(c, term_color);
        if (++term_col >= VGA_WIDTH) {
            term_col = 0;
            if (++term_row >= VGA_HEIGHT) term_scroll();
        }
    }
}

void term_write(const char* str) {
    while (*str) term_putchar(*str++);
}

void term_setcolor(uint8_t color) {
    term_color = color;
}

// Simple keyboard reading (polling mode)
char read_key() {
    static const char scancode_ascii[] = {
        0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
        '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
        0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
        0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
        '*', 0, ' '
    };
    
    // Wait for key press
    while (!(inb(0x64) & 1));
    
    uint8_t scancode = inb(0x60);
    
    // Ignore key release
    if (scancode & 0x80) return 0;
    
    // Convert to ASCII
    if (scancode < sizeof(scancode_ascii)) {
        return scancode_ascii[scancode];
    }
    
    return 0;
}

// Get line input
void get_input(char* buffer, int max_len) {
    int pos = 0;
    char c;
    
    while (pos < max_len - 1) {
        c = read_key();
        
        if (c == '\n') {
            buffer[pos] = '\0';
            term_putchar('\n');
            break;
        } else if (c == '\b' && pos > 0) {
            pos--;
            term_putchar('\b');
        } else if (c && c != '\b') {
            buffer[pos++] = c;
            term_putchar(c);
        }
    }
}

// Commands
void cmd_help() {
    term_setcolor(0x0F);
    term_write("\nAvailable commands:\n");
    term_setcolor(0x0A);
    term_write("  help   - Show this help\n");
    term_write("  clear  - Clear screen\n");
    term_write("  about  - About HybridOS\n");
    term_write("  echo   - Echo text\n");
    term_write("  color  - Change color (0-F)\n");
    term_setcolor(0x07);
}

void cmd_about() {
    term_setcolor(0x0E);
    term_write("\n=== HybridOS v1.0 ===\n");
    term_setcolor(0x0B);
    term_write("Windows + Linux = Freedom!\n");
    term_setcolor(0x07);
    term_write("\nA hybrid operating system that combines\n");
    term_write("the best of both worlds.\n");
}

// Process command
void process_command(char* cmd) {
    if (strcmp(cmd, "help") == 0) {
        cmd_help();
    } else if (strcmp(cmd, "clear") == 0) {
        term_clear();
    } else if (strcmp(cmd, "about") == 0) {
        cmd_about();
    } else if (strcmp(cmd, "echo") == 0) {
        term_write("\nEcho: ");
        get_input(input_buffer, 256);
        term_write("\n");
        term_write(input_buffer);
        term_write("\n");
    } else if (strcmp(cmd, "color") == 0) {
        term_write("\nEnter color (0-F): ");
        char col[2];
        get_input(col, 2);
        if (col[0] >= '0' && col[0] <= '9') {
            term_color = col[0] - '0';
        } else if (col[0] >= 'A' && col[0] <= 'F') {
            term_color = 10 + (col[0] - 'A');
        } else if (col[0] >= 'a' && col[0] <= 'f') {
            term_color = 10 + (col[0] - 'a');
        }
    } else if (cmd[0] != '\0') {
        term_setcolor(0x0C);
        term_write("\nUnknown command: ");
        term_write(cmd);
        term_setcolor(0x07);
    }
}

// Simple logo
void show_logo() {
    term_clear();
    term_setcolor(0x0B);
    
    term_row = 8;
    term_col = 20;
    term_write("HybridOS - Windows + Linux");
    
    term_row = 10;
    term_col = 25;
    term_write("Booting system...");
    
    // Simple delay
    for (volatile int i = 0; i < 50000000; i++);
}

// Main kernel
void kernel_main(void) {
    // Initialize
    show_logo();
    term_clear();
    
    // Welcome
    term_setcolor(0x0B);
    term_write("================================================================================\n");
    term_setcolor(0x0F);
    term_write("                    Welcome to HybridOS v1.0                                    \n");
    term_setcolor(0x0B);
    term_write("================================================================================\n\n");
    
    term_setcolor(0x0E);
    term_write("System ready. Type 'help' for commands.\n\n");
    
    // Main loop
    while (1) {
        term_setcolor(0x0B);
        term_write("HybridOS> ");
        term_setcolor(0x07);
        
        get_input(input_buffer, 256);
        process_command(input_buffer);
    }
}
EOF

# Créer un boot.asm simple sans IDT
cat > kernel/boot_simple.asm << 'EOF'
; Simple bootloader without complex IDT
MBALIGN  equ  1 << 0
MEMINFO  equ  1 << 1
FLAGS    equ  MBALIGN | MEMINFO
MAGIC    equ  0x1BADB002
CHECKSUM equ -(MAGIC + FLAGS)

section .multiboot
align 4
    dd MAGIC
    dd FLAGS
    dd CHECKSUM

section .bss
align 16
stack_bottom:
    resb 16384
stack_top:

section .text
global _start:function (_start.end - _start)
_start:
    mov esp, stack_top
    
    ; Disable interrupts
    cli
    
    ; Call kernel
    extern kernel_main
    call kernel_main
    
    ; Hang
    cli
.hang:
    hlt
    jmp .hang
.end:
EOF

# Nouveau Makefile
cat > Makefile << 'EOF'
AS = nasm
CC = gcc
LD = ld

ASFLAGS = -felf32
CFLAGS = -m32 -ffreestanding -O2 -Wall -Wextra -fno-stack-protector -nostdlib
LDFLAGS = -melf_i386 -T kernel.ld

all: HybridOS.iso

boot.o: kernel/boot_simple.asm
	$(AS) $(ASFLAGS) kernel/boot_simple.asm -o boot.o

kernel.o: kernel/kernel_simple.c
	$(CC) $(CFLAGS) -c kernel/kernel_simple.c -o kernel.o

kernel.elf: boot.o kernel.o
	$(LD) $(LDFLAGS) boot.o kernel.o -o kernel.elf

HybridOS.iso: kernel.elf
	@mkdir -p iso/boot/grub
	@cp kernel.elf iso/boot/
	@echo 'set timeout=0' > iso/boot/grub/grub.cfg
	@echo 'menuentry "HybridOS" {' >> iso/boot/grub/grub.cfg
	@echo '    multiboot /boot/kernel.elf' >> iso/boot/grub/grub.cfg
	@echo '    boot' >> iso/boot/grub/grub.cfg
	@echo '}' >> iso/boot/grub/grub.cfg
	@grub-mkrescue -o HybridOS.iso iso 2>/dev/null

clean:
	rm -f *.o *.elf *.iso
	rm -rf iso

run: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 128M -display sdl

run-gtk: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 128M -display gtk

run-curses: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 128M -display curses

.PHONY: all clean run
EOF

echo "🔨 Compilation du kernel simplifié..."
make clean
make

if [ -f "HybridOS.iso" ]; then
    echo "✅ Succès! Le kernel simplifié est prêt."
    echo ""
    echo "🚀 Pour tester:"
    echo "   make run         (avec SDL)"
    echo "   make run-curses  (dans le terminal)"
    echo ""
    echo "📝 Ce kernel utilise le polling au lieu des interruptions"
    echo "   pour éviter les problèmes de boucle."
fi
EOF

chmod +x fix-vmware.sh