#!/bin/bash
echo "🔍 Vérification du header multiboot..."

if [ -f "kernel.elf" ]; then
    # Cherche la signature multiboot (0x1BADB002) dans les premiers 8KB
    if hexdump -C kernel.elf | head -n 512 | grep -q "1b ad b0 02"; then
        echo "✅ Header multiboot trouvé!"
        echo "Position:"
        hexdump -C kernel.elf | head -n 512 | grep "1b ad b0 02"
    else
        echo "❌ Header multiboot NON trouvé!"
    fi
else
    echo "❌ kernel.elf n'existe pas!"
fi
