#!/bin/bash
# OpenClaw Auto-Inject - Progressive Memory Recall for OpenClaw
# Llamado automáticamente en cada turno de conversación

set -euo pipefail

BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"

# Source BrainX libraries
source "$BRAINX_HOME/lib/core.sh" 2>/dev/null || true
source "$BRAINX_HOME/lib/storage.sh" 2>/dev/null || true
source "$BRAINX_HOME/lib/relevance.sh" 2>/dev/null || true
source "$BRAINX_HOME/lib/dedup.sh" 2>/dev/null || true

# === CONFIG ===
RECALL_LIMIT="${RECALL_LIMIT:-10}"
RELEVANCE_THRESHOLD="${RELEVANCE_THRESHOLD:-70}"
DEDUP_ENABLED="${DEDUP_ENABLED:-true}"
SESSION_FILE="/tmp/openclaw-session-$(date +%Y%m%d).json"
MESSAGE_COUNT_FILE="/tmp/openclaw-msg-count"

# === GET CURRENT TOPIC ===
# Extrae el tema principal del último mensaje/consulta
extract_topic() {
    local query="$1"
    
    # Extraer palabras clave (simplificado, sin NLP pesado)
    echo "$query" | tr '[:upper:]' '[:lower:]' | \
        grep -oE '\b[a-z]{4,}\b' | \
        grep -vE '^(the|this|that|with|from|have|what|when|where|which|would|could|should|about|after|before|into|through|during|between|under|over|again|further|then|once|here|there|when|where|why|how|both|each|more|most|other|some|such|only|same|than|too|very|just|also|even|well|back|down|still|way|may|might|must|shall|will|been|being|does|doing|done|said|says|made|make|many|more|most|must|name|near|need|next|none|note|novel|now|obtain|of|off|often|old|on|once|only|onto|open|or|order|other|others|over|part|past|per|perhaps|put|quite|rather|really|regards|right|room|same|seem|seemed|seeming|seems|sense|several|shall|she|should|show|side|since|sincere|size|so|some|somehow|someone|something|sometime|sometimes|somewhere|still|such|system|take|ten|than|that|the|their|them|themselves|then|thence|there|thereafter|thereby|therefore|therein|thereupon|these|they|thick|thin|third|this|those|though|three|through|throughout|thru|thus|to|together|too|top|toward|towards|twelve|twenty|two|un|under|until|up|upon|us|used|using|various|very|via|was|we|well|were|what|whatever|when|whence|whenever|where|whereafter|whereas|whereby|wherein|whereupon|wherever|whether|which|while|whither|who|whoever|whole|whom|whose|why|will|with|within|without|would|yet|you|your|yours|yourself|yourselves)\b' | \
        sort | uniq -c | sort -rn | head -5 | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//'
}

# === PROGRESSIVE RECALL ===
progressive_recall() {
    local query="$1"
    local limit="${2:-$RECALL_LIMIT}"
    
    local topic
    topic=$(extract_topic "$query")
    
    if [[ -z "$topic" ]]; then
        echo "{}"
        return 0
    fi
    
    # Buscar en BrainX storage
    local results
    if [[ -x "$BRAINX_HOME/brainx-v2" ]]; then
        results=$("$BRAINX_HOME/brainx-v2" search "$topic" 2>/dev/null | head -$limit)
    else
        # Fallback: buscar directamente en archivos
        results=$(grep -r "$topic" "$BRAINX_HOME/storage"/*.json 2>/dev/null | \
            head -$limit | jq -s '.' 2>/dev/null || echo "[]")
    fi
    
    echo "$results"
}

# === DEDUP RESULTS ===
dedup_results() {
    local results="$1"
    
    if [[ "$DEDUP_ENABLED" != "true" ]]; then
        echo "$results"
        return 0
    fi
    
    # Usar dedup semántico de BrainX
    if command -v jq &>/dev/null && [[ -n "$results" ]] && [[ "$results" != "[]" ]]; then
        echo "$results" | jq -s 'unique_by(.content // .)' 2>/dev/null || echo "$results"
    else
        echo "$results"
    fi
}

# === FILTER BY RELEVANCE ===
filter_by_relevance() {
    local results="$1"
    local query="$2"
    local threshold="$RELEVANCE_THRESHOLD"
    
    if [[ ! -s "$results" ]] || [[ "$results" == "[]" ]]; then
        echo "[]"
        return 0
    fi
    
    # Filtrar por score de relevancia (simplificado)
    echo "$results" | jq --arg q "$query" --argjson t "$threshold" '
        map(select(.score // 0 >= $t)) | 
        sort_by(.score // 0) | 
        reverse
    ' 2>/dev/null || echo "$results"
}

# === FORMAT FOR OPENCLAW ===
format_for_injection() {
    local results="$1"
    local query="$2"
    
    if [[ -z "$results" ]] || [[ "$results" == "[]" ]]; then
        echo "<!-- No relevant memory found for: $query -->"
        return 0
    fi
    
    echo "## 🧠 Contexto Relevante (BrainX V2)"
    echo ""
    echo "$results" | jq -r '.[] | 
        "### \(.type // "Entry")\n\(.content // .)\n_Source: \(.timestamp // "unknown")_\n"
    ' 2>/dev/null || echo "$results"
}

# === CHECKPOINT SYSTEM ===
checkpoint() {
    local message_count
    
    if [[ -f "$MESSAGE_COUNT_FILE" ]]; then
        message_count=$(cat "$MESSAGE_COUNT_FILE")
    else
        message_count=0
    fi
    
    ((message_count++))
    echo "$message_count" > "$MESSAGE_COUNT_FILE"
    
    # Checkpoint cada 10 mensajes
    if [[ $((message_count % 10)) -eq 0 ]]; then
        echo "[BrainX] Checkpoint at message $message_count" >&2
        
        # Guardar contexto actual
        local timestamp
        timestamp=$(date -Iseconds)
        
        cat > "$SESSION_FILE" <<EOF
{
  "timestamp": "$timestamp",
  "message_count": $message_count,
  "checkpoint": true
}
EOF
    fi
    
    echo "$message_count"
}

# === SESSION CONSOLIDATION ===
consolidate_session() {
    if [[ ! -f "$SESSION_FILE" ]]; then
        return 0
    fi
    
    # Al final de sesión, consolidar entries por tema
    if [[ -x "$BRAINX_HOME/brainx-v2" ]]; then
        "$BRAINX_HOME/brainx-v2" optimize --consolidate 2>/dev/null || true
    fi
    
    rm -f "$SESSION_FILE" "$MESSAGE_COUNT_FILE"
}

# === MAIN INJECT FUNCTION ===
openclaw_inject() {
    local query="${*:-}"
    
    if [[ -z "$query" ]]; then
        echo "<!-- No query provided -->"
        return 0
    fi
    
    # Checkpoint
    checkpoint > /dev/null
    
    # Progressive recall
    local results
    results=$(progressive_recall "$query" "$RECALL_LIMIT")
    
    # Dedup
    results=$(dedup_results "$results")
    
    # Filter by relevance
    results=$(filter_by_relevance "$results" "$query")
    
    # Format for injection
    format_for_injection "$results" "$query"
}

# === CLI ===
case "${1:-}" in
    inject)
        shift
        openclaw_inject "$@"
        ;;
    recall)
        shift
        progressive_recall "${1:-}" "${2:-$RECALL_LIMIT}"
        ;;
    checkpoint)
        checkpoint
        ;;
    consolidate)
        consolidate_session
        ;;
    topic)
        shift
        extract_topic "${*:-}"
        ;;
    *)
        echo "Usage: $0 {inject|recall|checkpoint|consolidate|topic} [args]"
        echo ""
        echo "Examples:"
        echo "  $0 inject 'how to configure database'"
        echo "  $0 recall 'database' 5"
        echo "  $0 checkpoint"
        echo "  $0 consolidate"
        echo "  $0 topic 'quiero configurar postgresql en railway'"
        ;;
esac
