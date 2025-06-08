#!/bin/bash
echo "🚀 Lancement de HybridOS Ultimate..."

if [ -f "HybridOS.iso" ]; then
    if command -v qemu-system-i386 >/dev/null 2>&1; then
        echo "🎮 Démarrage en mode graphique..."
        qemu-system-i386 -cdrom HybridOS.iso -m 256M -display sdl 2>/dev/null || \
        qemu-system-i386 -cdrom HybridOS.iso -m 256M -display curses 2>/dev/null || \
        echo "❌ Erreur de démarrage QEMU"
    else
        echo "❌ QEMU non installé!"
    fi
else
    echo "❌ HybridOS.iso non trouvé! Exécutez d'abord l'installation."
fi
