#!/bin/bash
# Caching Functions
# lib/caching.sh

set -euo pipefail

# === CACHE DIRECTORY ===
CACHE_DIR="$BRAINX_HOME/.cache"
CACHE_TTL=${CACHE_TTL:-3600}

# === CACHE KEY ===
cache_key() {
    local input="$1"
    echo "$input" | md5sum | cut -d' ' -f1
}

# === GET CACHED ===
cache_get() {
    local key="$1"
    local cache_file="$CACHE_DIR/$key.json"
    
    if [[ "${CACHE_ENABLED:-true}" != "true" ]]; then
        return 1
    fi
    
    if [[ -f "$cache_file" ]]; then
        # Check TTL
        local modified
        modified=$(stat -c %Y "$cache_file")
        local now
        now=$(date +%s)
        
        if [[ $((now - modified)) -lt $CACHE_TTL ]]; then
            cat "$cache_file"
            return 0
        else
            rm "$cache_file"
        fi
    fi
    
    return 1
}

# === SET CACHED ===
cache_set() {
    local key="$1"
    local value="$2"
    local cache_file="$CACHE_DIR/$key.json"
    
    if [[ "${CACHE_ENABLED:-true}" != "true" ]]; then
        return 0
    fi
    
    mkdir -p "$CACHE_DIR"
    echo "$value" > "$cache_file"
}

# === CACHE SEARCH ===
cache_search() {
    local query="$1"
    local key
    key=$(cache_key "search:$query")
    
    if cache_get "$key"; then
        brainx_log DEBUG "Cache hit for search: $query"
        return 0
    fi
    
    brainx_log DEBUG "Cache miss for search: $query"
    return 1
}

# === RESPONSE CACHING ===
# Cache LLM responses for identical queries
cache_response_get() {
    local query="$1"
    local context_hash="${2:-}"
    local key
    key=$(cache_key "resp:${query}:${context_hash}")
    
    if [[ "${RESPONSE_CACHE_ENABLED:-true}" != "true" ]]; then
        return 1
    fi
    
    local cached
    if cached=$(cache_get "$key" 2>/dev/null); then
        local hit_time
        hit_time=$(echo "$cached" | jq -r '.cached_at // empty')
        local response
        response=$(echo "$cached" | jq -r '.response // empty')
        
        if [[ -n "$hit_time" && -n "$response" ]]; then
            brainx_log INFO "Response cache HIT for query"
            echo "$response"
            return 0
        fi
    fi
    
    return 1
}

cache_response_set() {
    local query="$1"
    local response="$2"
    local context_hash="${3:-}"
    local key
    key=$(cache_key "resp:${query}:${context_hash}")
    
    if [[ "${RESPONSE_CACHE_ENABLED:-true}" != "true" ]]; then
        return 0
    fi
    
    # Only cache if response is substantial
    local resp_tokens
    resp_tokens=$(count_tokens_estimate "$response")
    if [[ $resp_tokens -lt 20 ]]; then
        return 0
    fi
    
    local cache_data
    cache_data=$(jq -n \
        --arg query "$query" \
        --arg response "$response" \
        --arg cached_at "$(date -Iseconds)" \
        '{query: $query, response: $response, cached_at: $cached_at}')
    
    cache_set "$key" "$cache_data"
    brainx_log INFO "Response cached for query"
}

# === SEMANTIC QUERY MATCHING ===
# Find similar cached queries using fuzzy matching
cache_find_similar() {
    local query="$1"
    local similarity_threshold="${SIMILARITY_THRESHOLD:-0.85}"
    
    if [[ "${SEMANTIC_CACHE:-true}" != "true" ]]; then
        return 1
    fi
    
    # Normalize query for comparison
    local normalized_query
    normalized_query=$(echo "$query" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    
    # Search cache files for similar queries
    for cache_file in "$CACHE_DIR"/*.json; do
        [[ -f "$cache_file" ]] || continue
        
        local cached_query
        cached_query=$(jq -r '.query // empty' "$cache_file" 2>/dev/null)
        
        if [[ -z "$cached_query" ]]; then
            continue
        fi
        
        local normalized_cached
        normalized_cached=$(echo "$cached_query" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
        
        # Simple similarity check (can be enhanced with embeddings)
        if [[ "$normalized_cached" == *"$normalized_query"* ]] || [[ "$normalized_query" == *"$normalized_cached"* ]]; then
            jq -r '.response // empty' "$cache_file"
            brainx_log INFO "Semantic cache hit (fuzzy match)"
            return 0
        fi
    done
    
    return 1
}
