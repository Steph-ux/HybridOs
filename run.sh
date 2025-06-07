#!/bin/bash
echo "🚀 Lancement de HybridOS..."

# Essaie différentes méthodes jusqu'à ce qu'une marche
if command -v qemu-system-i386 >/dev/null 2>&1; then
    # Méthode 1: SDL
    qemu-system-i386 -cdrom HybridOS.iso -display sdl 2>/dev/null || \
    # Méthode 2: Curses
    qemu-system-i386 -cdrom HybridOS.iso -curses 2>/dev/null || \
    # Méthode 3: VNC
    (qemu-system-i386 -cdrom HybridOS.iso -vnc :1 & echo "VNC sur localhost:5901")
else
    echo "❌ QEMU non installé!"
fi
