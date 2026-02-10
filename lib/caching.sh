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
