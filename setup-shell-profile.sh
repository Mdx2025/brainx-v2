#!/bin/bash
# BrainX V2 Shell Profile Setup
# Agrega auto-loading del wrapper a ~/.bashrc y ~/.zshrc

SHELLRC_SOURCE='[ -f "/home/clawd/.openclaw/workspace/skills/brainx-v2/agent-wrapper.shellrc.sh" ] && source "/home/clawd/.openclaw/workspace/skills/brainx-v2/agent-wrapper.shellrc.sh"'

add_to_shellrc() {
    local file="$1"
    local marker="# BrainX V2 Auto-Load"

    if [ ! -f "$file" ]; then
        touch "$file"
    fi

    if ! grep -q "$marker" "$file" 2>/dev/null; then
        echo "" >> "$file"
        echo "$marker" >> "$file"
        echo "$SHELLRC_SOURCE" >> "$file"
        echo "✅ Agregado a $file"
    else
        echo "⏭ Ya configurado: $file"
    fi
}

echo "BrainX V2 Shell Profile Setup"
echo "=============================="
echo ""

add_to_shellrc "$HOME/.bashrc"
add_to_shellrc "$HOME/.zshrc"

echo ""
echo "✅ Auto-loading configurado!"
echo ""
echo "Para activar ahora (sin reiniciar):"
echo "  source ~/.bashrc"
