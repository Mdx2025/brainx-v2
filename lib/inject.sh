#!/bin/bash
# Memory Injection Pipeline
# lib/inject.sh

set -euo pipefail

# === INJECT MEMORIES ===
inject_memories() {
    local query="$1"
    
    brainx_log INFO "Inject pipeline for query: $query"
    
    # Step 1: Check response cache (NEW)
    if [[ "${RESPONSE_CACHE_ENABLED:-true}" == "true" ]]; then
        local cached_response
        if cached_response=$(cache_find_similar "$query"); then
            echo "$cached_response"
            return 0
        fi
    fi
    
    # Step 2: Search memories
    local memories
    memories=$(storage_search "$query")
    
    # Step 3: Semantic deduplication (NEW)
    if [[ "${DEDUP_ENABLED:-true}" == "true" ]] && [[ -n "$memories" ]]; then
        memories=$(dedup_memories "$memories")
    fi
    
    # Step 4: Score and filter
    local relevant
    relevant=$(filter_threshold "$SCORE_THRESHOLD" "$memories")
    
    # Step 5: Build context
    local context
    context=$(build_context "$query")
    
    # Step 6: Prune context with local model (NEW)
    if [[ "${LOCAL_COMPRESS_ENABLED:-true}" == "true" ]] && [[ -n "$context" ]]; then
        local pruned_context
        if pruned_context=$(prune_context_local "$query" "$context" 2>/dev/null); then
            if [[ -n "$pruned_context" ]]; then
                context="$pruned_context"
                brainx_log DEBUG "Context pruned with local model"
            fi
        fi
    fi
    
    # Step 7: Compress if needed
    local compressed
    compressed=$(compress_tokens "$context")
    
    # Step 8: Semantic compression for large contexts (NEW)
    if [[ "${SEMANTIC_COMPRESS:-true}" == "true" ]]; then
        local token_count
        token_count=$(count_tokens_estimate "$compressed")
        if [[ $token_count -gt $COMPRESS_THRESHOLD ]]; then
            compressed=$(compress_semantic "$compressed" "$((COMPRESS_THRESHOLD / 2))")
            brainx_log DEBUG "Applied semantic compression"
        fi
    fi
    
    # Step 9: Progressive summarization if still too large (NEW)
    if [[ "${SUMMARIZER_ENABLED:-true}" == "true" ]]; then
        local final_tokens
        final_tokens=$(count_tokens_estimate "$compressed")
        if [[ $final_tokens -gt $MAX_HISTORY_TOKENS ]]; then
            compressed=$(manage_context_window "$compressed" "$MAX_HISTORY_TOKENS")
            brainx_log DEBUG "Applied progressive summarization"
        fi
    fi
    
    # Step 10: Format for LLM
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
