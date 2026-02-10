#!/bin/bash
# BrainX V2 Auto-Load for Shell
# Agregar a ~/.bashrc o ~/.zshrc:
#   source /home/clawd/.openclaw/workspace/skills/brainx-v2/agent-wrapper.shellrc.sh
#
# Esto carga automáticamente el wrapper para el workspace actual

BRAINX_WRAPPER_SHELLRC="/home/clawd/.openclaw/workspace/skills/brainx-v2/agent-wrapper.shellrc.sh"

# Detectar workspace desde PWD
_auto_detect_workspace() {
    local pwd="$PWD"
    if [[ "$pwd" =~ /home/clawd/.openclaw/workspace-([^/]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# Cargar wrapper si estamos en un workspace
_load_brainx_wrapper() {
    local ws="$(_auto_detect_workspace)"
    if [ -n "$ws" ] && [ -f "/home/clawd/.openclaw/workspace-$ws/brainx-wrapper/agent-wrapper" ]; then
        source "/home/clawd/.openclaw/workspace-$ws/brainx-wrapper/agent-wrapper" 2>/dev/null
    fi
}

# Auto-load en cd (solo si no está ya cargado)
_auto_load_on_cd() {
    if [ -z "$BRAINX_AUTOLOADED" ]; then
        _load_brainx_wrapper
        export BRAINX_AUTOLOADED=1
    fi
}

# Ejecutar auto-load
_load_brainx_wrapper

echo "✅ BrainX V2 Auto-Load: $(_auto_detect_workspace)"

# Alias útiles
alias brainx-status='health_check 2>/dev/null || echo "Wrapper no disponible"'
alias brainx-search='search_memory'
alias brainx-agents='cat /home/clawd/.openclaw/.brainx-agents-registry'
