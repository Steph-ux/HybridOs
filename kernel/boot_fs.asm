; Bootloader for File System kernel
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
    resb 32768  ; 32KB stack for file system operations
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
