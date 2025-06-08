#!/bin/bash
echo "🚀 Lancement de HybridOS Ultimate v2.0 (CORRIGÉ)..."

if [ ! -f "HybridOS.iso" ]; then
    echo "❌ HybridOS.iso non trouvé! Compilez d'abord avec: make"
    exit 1
fi

echo "🎮 Lancement en mode graphique..."
qemu-system-i386 -cdrom HybridOS.iso -m 256M -display sdl 2>/dev/null || \
qemu-system-i386 -cdrom HybridOS.iso -m 256M -display curses 2>/dev/null || \
echo "❌ Erreur de démarrage QEMU"
