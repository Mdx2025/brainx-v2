#!/bin/bash
# Context Building Functions
# lib/context.sh

set -euo pipefail

# === BUILD CONTEXT ===
build_context() {
    local query="$1"
    local max_tokens="${2:-4000}"
    
    local context_parts=()
    local total_tokens=0
    
    # Search memories
    local memories
    memories=$(storage_search "$query")
    
    while IFS= read -r memory_line; do
        # Skip empty lines
        [[ -z "$memory_line" ]] && continue
        
        local id tier
        id=$(echo "$memory_line" | cut -d: -f1)
        tier=$(echo "$memory_line" | cut -d: -f2)
        
        # Skip if id is empty
        [[ -z "$id" ]] && continue
        
        local memory_json
        memory_json=$(storage_get "$id" 2>/dev/null) || continue
        
        local type content timestamp
        type=$(echo "$memory_json" | jq -r '.type')
        content=$(echo "$memory_json" | jq -r '.content')
        timestamp=$(echo "$memory_json" | jq -r '.timestamp')
        
        local part
        part=$(cat <<EOF
## Memory [$type] - $timestamp
$content
EOF
)
        local tokens
        tokens=$(estimate_tokens "$part")
        
        if [[ $((total_tokens + tokens)) -lt $max_tokens ]]; then
            context_parts+=("$part")
            total_tokens=$((total_tokens + tokens))
        fi
    done <<< "$memories"
    
    # Search second-brain
    local sb_results
    sb_results=$(sb_search "$query")
    
    while IFS= read -r sb_line; do
        local tokens
        tokens=$(estimate_tokens "$sb_line")
        
        if [[ $((total_tokens + tokens)) -lt $max_tokens ]]; then
            context_parts+=("$sb_line")
            total_tokens=$((total_tokens + tokens))
        fi
    done <<< "$sb_results"
    
    # Output context
    {
        echo "# Context"
        echo ""
        for part in "${context_parts[@]}"; do
            echo "$part"
            echo ""
        done
    }
}

# === FORMAT FOR LLM ===
format_injection() {
    local context="$1"
    local query="$2"
    
    cat <<EOF
## User Query
$query

## Relevant Context
$context

## Instructions
Use the context above to answer the query. If the context doesn't contain relevant information, say so.
EOF
}
