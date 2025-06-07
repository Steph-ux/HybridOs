#!/bin/bash
# Script d'installation du système de fichiers virtuel pour HybridOS

echo "🚀 Installation du Système de Fichiers Virtuel HybridOS..."
echo ""

# Backup du kernel actuel
if [ -f "kernel/kernel_simple.c" ]; then
    cp kernel/kernel_simple.c kernel/kernel_simple_backup.c
    echo "✅ Backup créé: kernel_simple_backup.c"
fi

# Créer le nouveau kernel avec système de fichiers
echo "📝 Création du kernel avec système de fichiers..."
cp kernel/kernel_simple.c kernel/kernel_nofs.c  # Garder l'ancien

# Le code du système de fichiers est déjà dans l'artifact précédent
# On va créer un boot.asm simple compatible
cat > kernel/boot_fs.asm << 'EOF'
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
EOF

# Mise à jour du Makefile pour compiler le kernel avec FS
cat > Makefile << 'EOF'
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
EOF

# Copier le nouveau kernel avec système de fichiers
echo "📁 Installation du kernel avec système de fichiers..."
# Le code est déjà dans l'artifact hybrid-filesystem, on suppose qu'il a été copié dans kernel/kernel.c

# Instructions pour l'utilisateur
cat > FILESYSTEM_README.txt << 'EOF'
=== HybridOS File System Edition ===

NOUVELLES COMMANDES:
-------------------
ls [path]        - Liste le contenu d'un répertoire
cd <path>        - Change de répertoire
pwd              - Affiche le répertoire courant
mkdir <nom>      - Crée un répertoire
touch <nom>      - Crée un fichier vide
cat <fichier>    - Affiche le contenu d'un fichier
echo text        - Affiche du texte
echo text > file - Écrit du texte dans un fichier
rm <fichier>     - Supprime un fichier ou répertoire vide
tree             - Affiche l'arborescence
clear            - Efface l'écran
help             - Affiche l'aide

STRUCTURE DES FICHIERS:
----------------------
/
├── home/        (Répertoires utilisateurs)
│   └── user/
│       └── readme.txt
├── bin/         (Exécutables)
├── etc/         (Configuration)
│   ├── motd     (Message du jour)
│   └── version  (Version du système)
├── tmp/         (Fichiers temporaires)
└── var/         (Données variables)

EXEMPLES:
---------
cd /home/user
echo "Hello World" > hello.txt
cat hello.txt
mkdir projects
cd projects
touch main.c
ls
cd ..
tree

NOTES:
------
- Les fichiers sont stockés en RAM
- Limite: 128 fichiers, 4KB par fichier
- Redémarrage = perte des données
EOF

echo ""
echo "✅ Installation terminée!"
echo ""
echo "📋 Pour compiler et tester:"
echo "   make fs      # Compile avec système de fichiers"
echo "   make run     # Lance l'OS"
echo ""
echo "📖 Lisez FILESYSTEM_README.txt pour la documentation"
echo ""
echo "🎯 Exemple rapide:"
echo '   echo "Hello" > test.txt'
echo "   cat test.txt"
echo "   mkdir mydir"
echo "   cd mydir"
echo "   pwd"