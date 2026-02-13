#!/bin/bash
# OpenClaw Memory Hook - Unified Memory Injection System
# Integra: BrainX V2 inject + memory-inyection + lightweight recall
#
# Uso:
#   source openclaw-memory-hook.sh
#   openclaw_recall "query"           # Buscar contexto relevante
#   openclaw_inject_context "query"   # Inyectar contexto formateado
#   openclaw_checkpoint               # Guardar checkpoint de sesión

set -uo pipefail

# === CONFIG ===
BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"
MEMORY_INYECTION_HOME="${MEMORY_INYECTION_HOME:-/home/clawd/.openclaw/extensions/memory-inyection}"
RECALL_LIMIT="${RECALL_LIMIT:-10}"
MIN_RELEVANCE="${MIN_RELEVANCE:-50}"
SESSION_FILE="/tmp/openclaw-session-$(date +%Y%m%d).json"

# === DETECT AVAILABLE SYSTEMS ===
has_brainx_v2() {
    [[ -x "$BRAINX_HOME/brainx-v2" ]]
}

has_memory_inyection() {
    [[ -d "$MEMORY_INYECTION_HOME" ]]
}

# === PRIMARY: BrainX V2 Inject Pipeline ===
brainx_inject_query() {
    local query="$1"
    local limit="${2:-$RECALL_LIMIT}"
    
    if ! has_brainx_v2; then
        echo "# BrainX V2 not available, using fallback"
        return 1
    fi
    
    # Use BrainX V2 full pipeline
    "$BRAINX_HOME/brainx-v2" inject "$query" 2>/dev/null || return 1
}

# === SECONDARY: Lightweight Grep+JQ Recall ===
lightweight_recall() {
    local query="$1"
    local limit="${2:-$RECALL_LIMIT}"
    
    local storage_dir="$BRAINX_HOME/storage"
    
    # Extract keywords
    local keywords
    keywords=$(echo "$query" | tr '[:upper:]' '[:lower:]' | \
        grep -oE '\b[a-z]{4,}\b' | \
        grep -vE '^(this|that|with|from|have|what|when|where|which|would|could|should|about|other|some|such|only|same|than|very|just|also|even|well|back|down|still|will|been|being|does|done|said|made|make|many|more|most|must|name|need|next|note|then|this|those|through|thus|very|what|when|where|which|while|with|would|your)\b' | \
        sort -u | head -5)
    
    if [[ -z "$keywords" ]]; then
        return 0
    fi
    
    echo "## 🧠 Contexto Ligero (Recall)"
    echo ""
    
    local found=0
    for keyword in $keywords; do
        # Search hot first, then warm
        for tier in hot warm; do
            local matches
            matches=$(grep -rli "$keyword" "$storage_dir/$tier"/*.json 2>/dev/null | head -5)
            
            for file in $matches; do
                if [[ -f "$file" ]] && [[ $found -lt $limit ]]; then
                    local content type timestamp
                    content=$(jq -r '.content // empty' "$file" 2>/dev/null)
                    type=$(jq -r '.type // "memory"' "$file" 2>/dev/null)
                    timestamp=$(jq -r '.timestamp // "unknown"' "$file" 2>/dev/null)
                    
                    if [[ -n "$content" ]]; then
                        echo "### $type"
                        echo "$content"
                        echo "_Source: $timestamp_"
                        echo ""
                        ((found++))
                    fi
                fi
            done
        done
    done
    
    if [[ $found -eq 0 ]]; then
        echo "<!-- No lightweight matches found -->"
    fi
}

# === UNIFIED RECALL ===
openclaw_recall() {
    local query="$1"
    local limit="${2:-$RECALL_LIMIT}"
    local mode="${3:-auto}"  # auto, full, light
    
    if [[ -z "$query" ]]; then
        echo "<!-- No query provided -->"
        return 0
    fi
    
    case "$mode" in
        full)
            brainx_inject_query "$query" "$limit"
            ;;
        light)
            lightweight_recall "$query" "$limit"
            ;;
        auto|*)
            # Try BrainX V2 first, fallback to lightweight
            if has_brainx_v2; then
                brainx_inject_query "$query" "$limit" || lightweight_recall "$query" "$limit"
            else
                lightweight_recall "$query" "$limit"
            fi
            ;;
    esac
}

# === INJECT FORMATTED CONTEXT ===
openclaw_inject_context() {
    local query="$1"
    local limit="${2:-$RECALL_LIMIT}"
    
    if [[ -z "$query" ]]; then
        echo ""
        return 0
    fi
    
    echo "<context_injection>"
    echo "<query>$query</query>"
    echo "<recall_mode>auto</recall_mode>"
    openclaw_recall "$query" "$limit" "auto"
    echo "</context_injection>"
}

# === CHECKPOINT SYSTEM ===
openclaw_checkpoint() {
    local context="${1:-session}"
    local timestamp
    timestamp=$(date -Iseconds)
    
    local checkpoint_data
    checkpoint_data=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "context": "$context",
  "brainx_available": $(has_brainx_v2 && echo "true" || echo "false"),
  "memory_inyection_available": $(has_memory_inyection && echo "true" || echo "false")
}
EOF
)
    
    echo "$checkpoint_data" > "$SESSION_FILE"
    
    # Also save to BrainX V2 if available
    if has_brainx_v2; then
        "$BRAINX_HOME/brainx-v2" add action "Session checkpoint" "$context" warm 2>/dev/null || true
    fi
    
    echo "Checkpoint saved: $timestamp"
}

# === SESSION CONSOLIDATION ===
openclaw_consolidate() {
    if [[ -f "$SESSION_FILE" ]]; then
        if has_brainx_v2; then
            "$BRAINX_HOME/brainx-v2" hook end "Session consolidated" 2>/dev/null || true
        fi
        rm -f "$SESSION_FILE"
        echo "Session consolidated"
    fi
}

# === STATUS ===
openclaw_memory_status() {
    echo "## 🧠 OpenClaw Memory System Status"
    echo ""
    echo "| Sistema | Disponible | Path |"
    echo "|---------|------------|------|"
    echo "| BrainX V2 | $(has_brainx_v2 && echo '✅' || echo '❌') | $BRAINX_HOME |"
    echo "| Memory-Inyection | $(has_memory_inyection && echo '✅' || echo '❌') | $MEMORY_INYECTION_HOME |"
    echo ""
    
    if has_brainx_v2; then
        echo "### BrainX V2 Stats"
        "$BRAINX_HOME/brainx-v2" stats 2>/dev/null || echo "Stats unavailable"
    fi
}

# === CLI ===
case "${1:-}" in
    recall)
        shift
        openclaw_recall "$@"
        ;;
    inject)
        shift
        openclaw_inject_context "$@"
        ;;
    checkpoint)
        shift
        openclaw_checkpoint "${1:-session}"
        ;;
    consolidate)
        openclaw_consolidate
        ;;
    status)
        openclaw_memory_status
        ;;
    *)
        cat <<EOF
OpenClaw Memory Hook v1.0
Integra BrainX V2 + Memory-Inyection + Lightweight Recall

Usage: $0 <command> [args]

Commands:
  recall <query> [limit] [mode]    Search memories (mode: auto|full|light)
  inject <query> [limit]           Get formatted context for injection
  checkpoint [context]             Save session checkpoint
  consolidate                      End session and consolidate
  status                           Show system status

Examples:
  $0 recall "database configuration"
  $0 inject "railway deployment" 5
  $0 checkpoint "working on emailbot"
  $0 consolidate
  $0 status

Integration:
  source openclaw-memory-hook.sh
  openclaw_recall "query"
  openclaw_inject_context "query"
EOF
        ;;
esac
