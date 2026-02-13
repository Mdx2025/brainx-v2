#!/bin/bash
# BrainX Memory Guardian v1.0
# Previene olvido en sesiones largas mediante compresión y resúmenes automáticos
#
# Uso: source brainx-memory-guardian.sh && brainx_guardian_init <agent_id> [max_size_mb]
#
# Este script debe ser SOURCED (no ejecutado) desde auto-integrate.sh

# === CONFIG ===
GUARDIAN_CONF="${GUARDIAN_CONF:-/home/clawd/.openclaw/workspace/skills/brainx-v2/config/guardian.conf}"
BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"
BRAINX_CLI="$BRAINX_HOME/brainx-v2"

# Cargar config si existe
[[ -f "$GUARDIAN_CONF" ]] && source "$GUARDIAN_CONF"

# Defaults
MAX_SESSION_SIZE_MB="${MAX_SESSION_SIZE_MB:-3}"
MESSAGES_BEFORE_SUMMARY="${MESSAGES_BEFORE_SUMMARY:-50}"
BRAINX_TIER="${BRAINX_TIER:-warm}"
ENABLED="${ENABLED:-true}"

# Variables de estado
GUARDIAN_AGENT_ID=""
GUARDIAN_WORKSPACE=""
GUARDIAN_SESSION_FILE=""
GUARDIAN_MSG_COUNT=0
GUARDIAN_LAST_SUMMARY_ID=""

# === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === LOGGING ===
guardian_log() {
    local level="$1"
    shift
    local msg="[BrainX Guardian] $*"
    case "$level" in
        ERROR) echo -e "${RED}[ERROR] $msg${NC}" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN] $msg${NC}" ;;
        INFO)  echo -e "${GREEN}[INFO] $msg${NC}" ;;
        DEBUG) [[ "$DEBUG_MODE" == "true" ]] && echo -e "${BLUE}[DEBUG] $msg${NC}" ;;
    esac
}

# === INICIALIZACIÓN ===
brainx_guardian_init() {
    GUARDIAN_AGENT_ID="${1:-support}"
    GUARDIAN_WORKSPACE="/home/clawd/.openclaw/workspace-${GUARDIAN_AGENT_ID}"
    GUARDIAN_SESSION_FILE="$GUARDIAN_WORKSPACE/session.jsonl"
    
    if [[ ! -f "$GUARDIAN_SESSION_FILE" ]]; then
        guardian_log WARN "Session file no existe: $GUARDIAN_SESSION_FILE"
        return 1
    fi
    
    # Contar mensajes actuales
    GUARDIAN_MSG_COUNT=$(wc -l < "$GUARDIAN_SESSION_FILE" 2>/dev/null || echo 0)
    
    guardian_log INFO "Inicializado para @$GUARDIAN_AGENT_ID"
    guardian_log INFO "  Session: $GUARDIAN_SESSION_FILE"
    guardian_log INFO "  Mensajes: $GUARDIAN_MSG_COUNT"
    guardian_log INFO "  Max size: ${MAX_SESSION_SIZE_MB}MB"
}

# === CHECK PRINCIPAL ===
brainx_guardian_check() {
    if [[ "$ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Verificar tamaño
    local size_mb=0
    if [[ -f "$GUARDIAN_SESSION_FILE" ]]; then
        size_mb=$(du -m "$GUARDIAN_SESSION_FILE" 2>/dev/null | cut -f1)
    fi
    
    # Verificar conteo de mensajes
    local msg_count=0
    if [[ -f "$GUARDIAN_SESSION_FILE" ]]; then
        msg_count=$(wc -l < "$GUARDIAN_SESSION_FILE" 2>/dev/null || echo 0)
    fi
    
    # Acciones según umbral
    if [[ $size_mb -ge $MAX_SESSION_SIZE_MB ]]; then
        guardian_log WARN "Session > ${MAX_SESSION_SIZE_MB}MB ($size_mb MB) - Comprimiendo..."
        brainx_guardian_compress
    elif [[ $((msg_count % MESSAGES_BEFORE_SUMMARY)) -eq 0 ]] && [[ $msg_count -gt 0 ]]; then
        guardian_log INFO " checkpoint - Generando resumen..."
        brainx_guardian_summarize
    fi
}

# === COMPRESIÓN DE SESIÓN ===
brainx_guardian_compress() {
    if [[ ! -f "$GUARDIAN_SESSION_FILE" ]]; then
        guardian_log WARN "No hay session para comprimir"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local compressed_id="compressed_${timestamp}"
    local temp_file="/tmp/guardian_compress_$$.jsonl"
    
    guardian_log INFO "Comprimiendo session..."
    
    # Comprimir contenido usando BrainX
    local content
    content=$(cat "$GUARDIAN_SESSION_FILE")
    
    if [[ -x "$BRAINX_CLI" ]]; then
        local compressed
        compressed=$("$BRAINX_CLI" optimize compress "$content" 2>/dev/null) || compressed="$content"
        
        # Guardar episodio comprimido en BrainX
        echo "$compressed" | "$BRAINX_CLI" add episode "Episodio comprimido @$GUARDIAN_AGENT_ID - $timestamp" "session-$GUARDIAN_AGENT_ID" "$BRAINX_TIER" 2>/dev/null
        
        guardian_log INFO "Episodio guardado en BrainX: $compressed_id"
    else
        # Fallback: solo guardar sin comprimir
        echo "$content" | "$BRAINX_CLI" add episode "Episodio raw @$GUARDIAN_AGENT_ID - $timestamp" "session-$GUARDIAN_AGENT_ID" "$BRAINX_TIER" 2>/dev/null
        guardian_log WARN "BrainX CLI no disponible - guardado sin compresión"
    fi
    
    # Truncar session a últimos 100 mensajes
    local keep_lines=100
    local total_lines=$(wc -l < "$GUARDIAN_SESSION_FILE")
    
    if [[ $total_lines -gt $keep_lines ]]; then
        tail -n $keep_lines "$GUARDIAN_SESSION_FILE" > "$temp_file"
        mv "$temp_file" "$GUARDIAN_SESSION_FILE"
        guardian_log INFO "Session truncada a últimos $keep_lines mensajes"
    fi
    
    GUARDIAN_MSG_COUNT=$keep_lines
}

# === RESUMEN DE SESIÓN ===
brainx_guardian_summarize() {
    if [[ ! -f "$GUARDIAN_SESSION_FILE" ]]; then
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local summary_id="summary_${timestamp}"
    
    # Extraer últimos N mensajes para resumir
    local recent_content
    recent_content=$(tail -n $MESSAGES_BEFORE_SUMMARY "$GUARDIAN_SESSION_FILE")
    
    # Generar resumen
    local summary="## Resumen de Sesión @$GUARDIAN_AGENT_ID - $timestamp

**Agent:** @$GUARDIAN_AGENT_ID
**Messages:** $GUARDIAN_MSG_COUNT

### Contenido reciente:
$recent_content

### Contexto activo:
$(brainx_inject_context "estado actual" 2>/dev/null || echo 'N/A')

---
*Generado por BrainX Guardian*"
    
    # Guardar resumen en BrainX
    if [[ -x "$BRAINX_CLI" ]]; then
        echo "$summary" | "$BRAINX_CLI" add summary "Resumen @$GUARDIAN_AGENT_ID - $timestamp" "session-$GUARDIAN_AGENT_ID" "$BRAINX_TIER" 2>/dev/null
        GUARDIAN_LAST_SUMMARY_ID="$summary_id"
        guardian_log INFO "Resumen guardado: $summary_id"
    fi
}

# === INYECCIÓN DE CONTEXTO ===
brainx_inject_context() {
    local query="${1:-estado actual}"
    local limit="${2:-5}"
    
    if [[ ! -x "$BRAINX_CLI" ]]; then
        echo ""
        return 1
    fi
    
    # Buscar resúmenes y episodios relacionados
    local context
    context=$("$BRAINX_CLI" search "$query" 2>/dev/null | head -$limit)
    
    # Buscar también resúmenes específicos del agent
    local summaries
    summaries=$("$BRAINX_CLI" search "summary $GUARDIAN_AGENT_ID" 2>/dev/null | head -3)
    
    if [[ -n "$context" ]]; then
        echo "=== CONTEXTO RELEVANTE ==="
        echo "$context"
        echo ""
        echo "=== RESÚMENES ANTERIORES ==="
        echo "$summaries"
        echo "============================"
    fi
}

# === STATUS ===
brainx_guardian_status() {
    echo "=== BrainX Memory Guardian Status ==="
    echo "Agent: @$GUARDIAN_AGENT_ID"
    echo "Enabled: $ENABLED"
    echo "Session: $GUARDIAN_SESSION_FILE"
    
    if [[ -f "$GUARDIAN_SESSION_FILE" ]]; then
        local size_mb=$(du -m "$GUARDIAN_SESSION_FILE" | cut -f1)
        local msg_count=$(wc -l < "$GUARDIAN_SESSION_FILE")
        echo "Size: ${size_mb}MB"
        echo "Messages: $msg_count"
        echo "Threshold: ${MAX_SESSION_SIZE_MB}MB"
        echo "Summary every: $MESSAGES_BEFORE_SUMMARY mensajes"
    else
        echo "Status: SIN SESIÓN ACTIVA"
    fi
    
    echo "Last summary: ${GUARDIAN_LAST_SUMMARY_ID:-None}"
}

# Auto-inicializar si se sourcea desde un workspace
_guardián_auto_init() {
    local workspace_path="${PWD}"
    local agent_id=""
    
    # Detectar agent desde path
    if [[ "$workspace_path" == *"workspace-"* ]]; then
        agent_id=$(basename "$workspace_path" | sed 's/workspace-//')
    elif [[ -n "$GUARDIAN_AGENT_ID" ]]; then
        agent_id="$GUARDIAN_AGENT_ID"
    fi
    
    if [[ -n "$agent_id" ]]; then
        brainx_guardian_init "$agent_id" 2>/dev/null
    fi
}

# Auto-init si workspace detected
_guardián_auto_init

guardian_log DEBUG "BrainX Guardian cargado"
