#!/bin/bash
echo "🐛 Démarrage de HybridOS en mode debug..."
qemu-system-i386 -cdrom HybridOS.iso -m 256M -d int -no-reboot -monitor stdio
