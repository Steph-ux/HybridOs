#!/bin/bash
set -e

echo "🔨 Building HybridOS..."

# Clean
make clean

# Build
make

if [ -f "HybridOS.iso" ]; then
    echo "✅ Build successful!"
    echo "📦 ISO size: $(du -h HybridOS.iso | cut -f1)"
    echo ""
    echo "🚀 To run: make run"
    echo "🐛 To debug: make debug"
else
    echo "❌ Build failed!"
    exit 1
fi
