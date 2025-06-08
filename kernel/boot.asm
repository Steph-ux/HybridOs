; Bootloader Ultimate avec support interruptions
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
    resb 32768  ; 32KB stack pour toutes les fonctionnalités
stack_top:

section .text
global _start:function (_start.end - _start)
_start:
    mov esp, stack_top
    cli
    
    extern kernel_main
    call kernel_main
    
.hang:
    hlt
    jmp .hang
.end:

; IDT support (simplifié pour compatibilité)
global idt_flush
idt_flush:
    mov eax, [esp+4]
    lidt [eax]
    ret
