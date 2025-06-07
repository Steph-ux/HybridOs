#!/bin/bash
# Installation complète de HybridOS avec toutes les fonctionnalités

echo "🚀 Installation de HybridOS Complete Edition..."
echo "   Avec clavier, commandes, animations, et plus!"

# Backup du kernel actuel
if [ -f "kernel/kernel.c" ]; then
    cp kernel/kernel.c kernel/kernel_backup.c
fi

# 1. Créer le nouveau boot.asm avec support IDT
cat > kernel/boot.asm << 'EOF'
; Multiboot header
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
    resb 32768  ; 32KB stack
stack_top:

section .text
global _start:function (_start.end - _start)
_start:
    mov esp, stack_top
    
    ; Call kernel
    extern kernel_main
    call kernel_main
    
    cli
.hang:
    hlt
    jmp .hang
.end:

; IDT functions
global idt_flush
idt_flush:
    mov eax, [esp+4]
    lidt [eax]
    ret

; ISR stubs
%macro ISR_NOERRCODE 1
    global isr%1
    isr%1:
        cli
        push byte 0
        push byte %1
        jmp isr_common_stub
%endmacro

%macro ISR_ERRCODE 1
    global isr%1
    isr%1:
        cli
        push byte %1
        jmp isr_common_stub
%endmacro

; IRQ stubs
%macro IRQ 2
    global irq%1
    irq%1:
        cli
        push byte 0
        push byte %2
        jmp irq_common_stub
%endmacro

; Define ISRs
ISR_NOERRCODE 0
ISR_NOERRCODE 1
ISR_NOERRCODE 2
ISR_NOERRCODE 3
ISR_NOERRCODE 4
ISR_NOERRCODE 5
ISR_NOERRCODE 6
ISR_NOERRCODE 7
ISR_ERRCODE   8
ISR_NOERRCODE 9
ISR_ERRCODE   10
ISR_ERRCODE   11
ISR_ERRCODE   12
ISR_ERRCODE   13
ISR_ERRCODE   14
ISR_NOERRCODE 15
ISR_NOERRCODE 16
ISR_NOERRCODE 17
ISR_NOERRCODE 18
ISR_NOERRCODE 19
ISR_NOERRCODE 20
ISR_NOERRCODE 21
ISR_NOERRCODE 22
ISR_NOERRCODE 23
ISR_NOERRCODE 24
ISR_NOERRCODE 25
ISR_NOERRCODE 26
ISR_NOERRCODE 27
ISR_NOERRCODE 28
ISR_NOERRCODE 29
ISR_NOERRCODE 30
ISR_NOERRCODE 31

; Define IRQs
IRQ 0, 32
IRQ 1, 33
IRQ 2, 34
IRQ 3, 35
IRQ 4, 36
IRQ 5, 37
IRQ 6, 38
IRQ 7, 39
IRQ 8, 40
IRQ 9, 41
IRQ 10, 42
IRQ 11, 43
IRQ 12, 44
IRQ 13, 45
IRQ 14, 46
IRQ 15, 47

; ISR handler
extern isr_handler
isr_common_stub:
    pusha
    
    mov ax, ds
    push eax
    
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    call isr_handler
    
    pop eax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    popa
    add esp, 8
    sti
    iret

; IRQ handler
extern irq_handler
irq_common_stub:
    pusha
    
    mov ax, ds
    push eax
    
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    call irq_handler
    
    pop ebx
    mov ds, bx
    mov es, bx
    mov fs, bx
    mov gs, bx
    
    popa
    add esp, 8
    sti
    iret
EOF

# 2. Créer le kernel simplifié mais complet
cat > kernel/kernel.c << 'EOF'
// Types de base
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long size_t;
#define NULL ((void*)0)
#define true 1
#define false 0

// VGA
#define VGA_WIDTH 80
#define VGA_HEIGHT 25
static uint16_t* const VGA_MEMORY = (uint16_t*)0xB8000;

// Colors
enum vga_color {
    BLACK = 0, BLUE = 1, GREEN = 2, CYAN = 3,
    RED = 4, MAGENTA = 5, BROWN = 6, LIGHT_GREY = 7,
    DARK_GREY = 8, LIGHT_BLUE = 9, LIGHT_GREEN = 10,
    LIGHT_CYAN = 11, LIGHT_RED = 12, LIGHT_MAGENTA = 13,
    YELLOW = 14, WHITE = 15
};

// Terminal state
static size_t term_row = 0;
static size_t term_col = 0;
static uint8_t term_color = 0x07;

// Keyboard buffer
static char kb_buffer[256];
static int kb_pos = 0;
static int shift = 0;

// Timer
static uint32_t tick_count = 0;

// I/O ports
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
    return *(unsigned char*)s1 - *(unsigned char*)s2;
}

// Terminal functions
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

// Enable cursor
void enable_cursor() {
    outb(0x3D4, 0x0A);
    outb(0x3D5, (inb(0x3D5) & 0xC0) | 14);
    outb(0x3D4, 0x0B);
    outb(0x3D5, (inb(0x3D5) & 0xE0) | 15);
}

void update_cursor() {
    uint16_t pos = term_row * VGA_WIDTH + term_col;
    outb(0x3D4, 0x0F);
    outb(0x3D5, (uint8_t)(pos & 0xFF));
    outb(0x3D4, 0x0E);
    outb(0x3D5, (uint8_t)((pos >> 8) & 0xFF));
}

// IDT structures
typedef struct {
    uint16_t base_lo;
    uint16_t sel;
    uint8_t always0;
    uint8_t flags;
    uint16_t base_hi;
} __attribute__((packed)) idt_entry_t;

typedef struct {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed)) idt_ptr_t;

typedef struct {
    uint32_t ds;
    uint32_t edi, esi, ebp, esp, ebx, edx, ecx, eax;
    uint32_t int_no, err_code;
    uint32_t eip, cs, eflags, useresp, ss;
} registers_t;

idt_entry_t idt_entries[256];
idt_ptr_t idt_ptr;

// External ISR/IRQ handlers
extern void isr0(); extern void isr1(); extern void isr2(); extern void isr3();
extern void isr4(); extern void isr5(); extern void isr6(); extern void isr7();
extern void isr8(); extern void isr9(); extern void isr10(); extern void isr11();
extern void isr12(); extern void isr13(); extern void isr14(); extern void isr15();
extern void isr16(); extern void isr17(); extern void isr18(); extern void isr19();
extern void isr20(); extern void isr21(); extern void isr22(); extern void isr23();
extern void isr24(); extern void isr25(); extern void isr26(); extern void isr27();
extern void isr28(); extern void isr29(); extern void isr30(); extern void isr31();
extern void irq0(); extern void irq1(); extern void irq2(); extern void irq3();
extern void irq4(); extern void irq5(); extern void irq6(); extern void irq7();
extern void irq8(); extern void irq9(); extern void irq10(); extern void irq11();
extern void irq12(); extern void irq13(); extern void irq14(); extern void irq15();
extern void idt_flush(uint32_t);

void idt_set_gate(uint8_t num, uint32_t base, uint16_t sel, uint8_t flags) {
    idt_entries[num].base_lo = base & 0xFFFF;
    idt_entries[num].base_hi = (base >> 16) & 0xFFFF;
    idt_entries[num].sel = sel;
    idt_entries[num].always0 = 0;
    idt_entries[num].flags = flags | 0x60;
}

void init_idt() {
    idt_ptr.limit = sizeof(idt_entry_t) * 256 - 1;
    idt_ptr.base = (uint32_t)&idt_entries;
    
    // Clear IDT
    for (int i = 0; i < 256; i++) {
        idt_set_gate(i, 0, 0, 0);
    }
    
    // ISRs
    idt_set_gate(0, (uint32_t)isr0, 0x08, 0x8E);
    idt_set_gate(1, (uint32_t)isr1, 0x08, 0x8E);
    // ... (autres ISRs si nécessaire)
    
    // IRQs
    idt_set_gate(32, (uint32_t)irq0, 0x08, 0x8E);  // Timer
    idt_set_gate(33, (uint32_t)irq1, 0x08, 0x8E);  // Keyboard
    
    // Remap PIC
    outb(0x20, 0x11); outb(0xA0, 0x11);
    outb(0x21, 0x20); outb(0xA1, 0x28);
    outb(0x21, 0x04); outb(0xA1, 0x02);
    outb(0x21, 0x01); outb(0xA1, 0x01);
    outb(0x21, 0x0);  outb(0xA1, 0x0);
    
    idt_flush((uint32_t)&idt_ptr);
}

// Keyboard scancode map
const char scancode_ascii[] = {
    0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
    0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
    '*', 0, ' '
};

// Timer handler
void timer_handler() {
    tick_count++;
    
    // Update clock every second (18 ticks)
    if (tick_count % 18 == 0) {
        // Save cursor
        size_t old_row = term_row, old_col = term_col;
        uint8_t old_color = term_color;
        
        // Display time in corner
        term_row = 0;
        term_col = VGA_WIDTH - 10;
        term_color = 0x1F;
        
        char time[9] = "00:00:00";
        uint32_t seconds = tick_count / 18;
        time[6] = '0' + ((seconds % 60) / 10);
        time[7] = '0' + (seconds % 10);
        time[3] = '0' + (((seconds / 60) % 60) / 10);
        time[4] = '0' + ((seconds / 60) % 10);
        time[0] = '0' + (((seconds / 3600) % 24) / 10);
        time[1] = '0' + ((seconds / 3600) % 10);
        
        term_write(time);
        
        // Restore cursor
        term_row = old_row;
        term_col = old_col;
        term_color = old_color;
        update_cursor();
    }
}

// Command processing
void process_command(char* cmd) {
    if (strcmp(cmd, "help") == 0) {
        term_setcolor(0x0F);
        term_write("\nAvailable commands:\n");
        term_setcolor(0x0A);
        term_write("  help     "); term_setcolor(0x07); term_write("- Show this help\n");
        term_setcolor(0x0A);
        term_write("  clear    "); term_setcolor(0x07); term_write("- Clear screen\n");
        term_setcolor(0x0A);
        term_write("  about    "); term_setcolor(0x07); term_write("- About HybridOS\n");
        term_setcolor(0x0A);
        term_write("  reboot   "); term_setcolor(0x07); term_write("- Restart system\n");
        term_setcolor(0x0A);
        term_write("  echo     "); term_setcolor(0x07); term_write("- Print text\n");
        term_setcolor(0x0A);
        term_write("  matrix   "); term_setcolor(0x07); term_write("- Matrix effect\n");
    }
    else if (strcmp(cmd, "clear") == 0) {
        term_clear();
    }
    else if (strcmp(cmd, "about") == 0) {
        term_setcolor(0x0E);
        term_write("\n=== HybridOS v1.0 ===\n");
        term_setcolor(0x0B);
        term_write("The Windows/Linux Hybrid System\n");
        term_setcolor(0x07);
        term_write("Features:\n");
        term_write("- Windows .exe support (soon)\n");
        term_write("- Linux compatibility\n");
        term_write("- Real-time clock\n");
        term_write("- Interactive shell\n");
    }
    else if (strcmp(cmd, "reboot") == 0) {
        term_setcolor(0x0C);
        term_write("\nRebooting...\n");
        outb(0x64, 0xFE);  // Reset via keyboard controller
    }
    else if (strcmp(cmd, "matrix") == 0) {
        term_clear();
        term_setcolor(0x0A);
        for (int i = 0; i < 200; i++) {
            term_col = i % VGA_WIDTH;
            term_row = (i / VGA_WIDTH) % VGA_HEIGHT;
            term_putchar('0' + (i % 10));
            for (volatile int j = 0; j < 1000000; j++);
        }
    }
    else if (cmd[0] != '\0') {
        term_setcolor(0x0C);
        term_write("\nUnknown command: ");
        term_write(cmd);
        term_setcolor(0x07);
        term_write("\nType 'help' for commands\n");
    }
}

// Keyboard handler
void keyboard_handler() {
    uint8_t scancode = inb(0x60);
    
    // Handle shift
    if (scancode == 0x2A || scancode == 0x36) {
        shift = 1;
        return;
    } else if (scancode == 0xAA || scancode == 0xB6) {
        shift = 0;
        return;
    }
    
    // Ignore key release
    if (scancode & 0x80) return;
    
    // Get ASCII
    char c = 0;
    if (scancode < sizeof(scancode_ascii)) {
        c = scancode_ascii[scancode];
        if (shift && c >= 'a' && c <= 'z') c -= 32;  // Uppercase
    }
    
    if (c) {
        if (c == '\b' && kb_pos > 0) {
            kb_pos--;
            term_putchar('\b');
            update_cursor();
        } else if (c == '\n') {
            kb_buffer[kb_pos] = '\0';
            term_putchar('\n');
            process_command(kb_buffer);
            term_setcolor(0x0B);
            term_write("HybridOS> ");
            term_setcolor(0x07);
            kb_pos = 0;
            update_cursor();
        } else if (kb_pos < 255) {
            kb_buffer[kb_pos++] = c;
            term_putchar(c);
            update_cursor();
        }
    }
}

// Interrupt handlers
void isr_handler(registers_t regs) {
    // Handle exceptions
}

void irq_handler(registers_t regs) {
    // Send EOI
    if (regs.int_no >= 40) outb(0xA0, 0x20);
    outb(0x20, 0x20);
    
    // Handle specific IRQs
    switch(regs.int_no) {
        case 32: timer_handler(); break;
        case 33: keyboard_handler(); break;
    }
}

// Boot logo
void show_logo() {
    term_clear();
    term_setcolor(0x0B);
    term_row = 5;
    
    const char* logo[] = {
        "    _   _       _          _     _ _____ _____",
        "   | | | |     | |        (_)   | |  _  /  ___|",
        "   | |_| |_   _| |__  _ __ _  __| | | | \\ `--.",
        "   |  _  | | | | '_ \\| '__| |/ _` | | | |`--. \\",
        "   | | | | |_| | |_) | |  | | (_| \\ \\_/ /\\__/ /",
        "   \\_| |_/\\__, |_.__/|_|  |_|\\__,_|\\___/\\____/",
        "           __/ |",
        "          |___/   Windows + Linux = Freedom!"
    };
    
    for (int i = 0; i < 8; i++) {
        term_col = (VGA_WIDTH - strlen(logo[i])) / 2;
        term_write(logo[i]);
        term_row++;
    }
    
    // Loading animation
    term_row = 15;
    term_col = 30;
    term_setcolor(0x0A);
    term_write("Loading HybridOS");
    
    for (int i = 0; i < 20; i++) {
        term_write(".");
        for (volatile int j = 0; j < 5000000; j++);
    }
}

// Timer init
void init_timer(uint32_t freq) {
    uint32_t divisor = 1193180 / freq;
    outb(0x43, 0x36);
    outb(0x40, divisor & 0xFF);
    outb(0x40, (divisor >> 8) & 0xFF);
}

// Main kernel
void kernel_main(void) {
    // Show boot logo
    show_logo();
    
    // Initialize
    term_clear();
    enable_cursor();
    init_idt();
    init_timer(18);
    
    // Enable interrupts
    __asm__ volatile ("sti");
    
    // Welcome
    term_setcolor(0x0B);
    term_write("================================================================================\n");
    term_setcolor(0x0F);
    term_write("              Welcome to HybridOS - The Future of Computing!                    \n");
    term_setcolor(0x0B);
    term_write("================================================================================\n\n");
    
    term_setcolor(0x0E);
    term_write("System ready. Type 'help' for available commands.\n\n");
    
    term_setcolor(0x0B);
    term_write("HybridOS> ");
    term_setcolor(0x07);
    
    // Main loop
    while (1) {
        __asm__ volatile ("hlt");
    }
}
EOF

# 3. Mise à jour du Makefile pour compiler tout
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

HybridOS.iso: kernel.elf
	@mkdir -p iso/boot/grub
	@cp kernel.elf iso/boot/
	@echo 'set timeout=0' > iso/boot/grub/grub.cfg
	@echo 'menuentry "HybridOS Complete" {' >> iso/boot/grub/grub.cfg
	@echo '    multiboot /boot/kernel.elf' >> iso/boot/grub/grub.cfg
	@echo '    boot' >> iso/boot/grub/grub.cfg
	@echo '}' >> iso/boot/grub/grub.cfg
	@grub-mkrescue -o HybridOS.iso iso 2>/dev/null

clean:
	rm -f *.o *.elf *.iso
	rm -rf iso

run: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 128M

run-debug: HybridOS.iso
	qemu-system-i386 -cdrom HybridOS.iso -m 128M -d int -no-reboot

.PHONY: all clean run run-debug
EOF

# 4. Compiler
echo ""
echo "🔨 Compilation de HybridOS Complete Edition..."
make clean
make

if [ -f "HybridOS.iso" ]; then
    echo ""
    echo "✅ Compilation réussie!"
    echo ""
    echo "🎮 Fonctionnalités disponibles:"
    echo "   ✓ Support clavier complet"
    echo "   ✓ Shell interactif avec commandes"
    echo "   ✓ Horloge temps réel"
    echo "   ✓ Animation de boot avec logo"
    echo "   ✓ Défilement du texte"
    echo "   ✓ Curseur clignotant"
    echo ""
    echo "📝 Commandes disponibles:"
    echo "   help   - Afficher l'aide"
    echo "   clear  - Effacer l'écran"
    echo "   about  - À propos de HybridOS"
    echo "   reboot - Redémarrer"
    echo "   matrix - Effet Matrix"
    echo ""
    echo "🚀 Pour lancer: make run"
    echo "🐛 Mode debug: make run-debug"
else
    echo "❌ Erreur de compilation!"
fi