#!/bin/bash
# Memory Injection Pipeline
# lib/inject.sh

set -euo pipefail

# === INJECT MEMORIES ===
inject_memories() {
    local query="$1"
    
    brainx_log INFO "Inject pipeline for query: $query"
    
    # Step 1: Search memories
    local memories
    memories=$(storage_search "$query")
    
    # Step 2: Score and filter
    local relevant
    relevant=$(filter_threshold "$SCORE_THRESHOLD" "$memories")
    
    # Step 3: Build context
    local context
    context=$(build_context "$query")
    
    # Step 4: Compress if needed
    local compressed
    compressed=$(compress_tokens "$context")
    
    # Step 5: Format for LLM
    local injection
    injection=$(format_injection "$compressed" "$query")
    
    echo "$injection"
}

# === BRAINX INJECT COMMAND ===
brainx_inject() {
    local query="${*:-}"
    
    if [[ -z "$query" ]]; then
        brainx_error "Usage: brainx-v2 inject <query>"
        return 1
    fi
    
    echo -e "${BOLD}Memory Injection Pipeline${NC}"
    echo "============================"
    echo ""
    
    inject_memories "$query"
}
