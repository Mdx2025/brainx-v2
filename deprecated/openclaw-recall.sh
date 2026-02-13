#!/bin/bash
# OpenClaw Auto-Recall - Simplified Progressive Memory Injection
# Sin dependencias complejas, solo grep + jq

set -uo pipefail

STORAGE_DIR="${STORAGE_DIR:-/home/clawd/.openclaw/workspace/skills/brainx-v2/storage}"
RECALL_LIMIT="${RECALL_LIMIT:-10}"
MIN_SCORE="${MIN_SCORE:-50}"

# === EXTRACT KEYWORDS ===
extract_keywords() {
    local text="$1"
    # Palabras clave simples (sin stopwords comunes)
    echo "$text" | tr '[:upper:]' '[:lower:]' | \
        grep -oE '\b[a-z]{4,}\b' | \
        grep -vE '^(this|that|with|from|have|what|when|where|which|would|could|should|about|after|before|into|through|during|between|under|over|again|further|then|once|here|there|other|some|such|only|same|than|too|very|just|also|even|well|back|down|still|might|must|shall|will|been|being|does|doing|done|said|says|made|make|many|more|most|must|name|near|need|next|none|note|novel|now|obtain|often|only|onto|open|order|over|part|past|perhaps|quite|rather|really|regards|right|room|same|seem|seemed|seeming|seems|sense|several|shall|show|side|since|sincere|size|some|somehow|someone|something|sometime|sometimes|somewhere|still|such|system|take|ten|than|that|their|them|themselves|then|thence|there|thereafter|thereby|therefore|therein|thereupon|these|they|thick|thin|third|this|those|though|three|through|throughout|thru|thus|together|toward|towards|twelve|twenty|under|until|upon|used|using|various|very|via|were|what|whatever|when|whence|whenever|where|whereafter|whereas|whereby|wherein|whereupon|wherever|whether|which|while|whither|who|whoever|whole|whom|whose|why|will|with|within|without|would|your|yours|yourself|yourselves)\b' | \
        sort | uniq -c | sort -rn | head -10 | awk '{print $2}'
}

# === SEARCH MEMORIES ===
search_memories() {
    local query="$1"
    local limit="${2:-$RECALL_LIMIT}"
    
    local keywords
    keywords=$(extract_keywords "$query")
    
    if [[ -z "$keywords" ]]; then
        echo "[]"
        return 0
    fi
    
    # Buscar en storage
    local results="[]"
    
    for keyword in $keywords; do
        # Buscar en hot y warm
        local matches
        matches=$(grep -rl "$keyword" "$STORAGE_DIR/hot" "$STORAGE_DIR/warm" 2>/dev/null | head -20)
        
        for file in $matches; do
            if [[ -f "$file" ]]; then
                local content
                content=$(cat "$file" 2>/dev/null)
                
                if [[ -n "$content" ]]; then
                    # Calcular score simple basado en matches
                    local score
                    score=$(echo "$content" | grep -oi "$keyword" | wc -l)
                    score=$((score * 10))
                    
                    # Agregar a results
                    results=$(echo "$results" | jq --argjson content "$content" --argjson score "$score" \
                        '. += [$content + {computed_score: $score}]' 2>/dev/null || echo "$results")
                fi
            fi
        done
    done
    
    # Filtrar por score y limitar
    echo "$results" | jq --argjson min "$MIN_SCORE" --argjson limit "$limit" \
        'map(select(.computed_score >= $min)) | sort_by(.computed_score) | reverse | .[:$limit]' 2>/dev/null || echo "[]"
}

# === FORMAT FOR OPENCLAW ===
format_context() {
    local results="$1"
    local query="$2"
    
    local count
    count=$(echo "$results" | jq 'length' 2>/dev/null || echo "0")
    
    if [[ "$count" -eq 0 ]]; then
        echo ""
        return 0
    fi
    
    echo "## 🧠 Contexto Relevante (Recall)"
    echo "_Query: $query_"
    echo ""
    
    echo "$results" | jq -r '.[] | 
        "### \(.type // "memory")\n\(.content // .)\n_Context: \(.context // "")_\n_Score: \(.computed_score // 0)_\n"'
}

# === DEDUP SIMPLE ===
dedup_simple() {
    local results="$1"
    
    # Dedup por content similar
    echo "$results" | jq 'unique_by(.content)' 2>/dev/null || echo "$results"
}

# === MAIN ===
main() {
    local query="${*:-}"
    
    if [[ -z "$query" ]]; then
        cat <<EOF
OpenClaw Auto-Recall v1.0

Usage: $0 <query>

Recalls relevant memories from BrainX V2 storage.

Examples:
  $0 "configurar postgresql"
  $0 "railway deployment"
  $0 "emailbot health check"
EOF
        return 0
    fi
    
    # Search
    local results
    results=$(search_memories "$query" "$RECALL_LIMIT")
    
    # Dedup
    results=$(dedup_simple "$results")
    
    # Format
    format_context "$results" "$query"
}

# Run
main "$@"
