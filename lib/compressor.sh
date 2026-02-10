#!/bin/bash
# Token Compression Functions
# lib/compressor.sh

set -euo pipefail

# === COMPRESS TOKENS ===
compress_tokens() {
    local text="$1"
    
    if [[ "${COMPRESS_ENABLED:-true}" != "true" ]]; then
        echo "$text"
        return 0
    fi
    
    local compressed="$text"
    
    # Remove extra whitespace
    compressed=$(echo "$compressed" | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')
    
    # Remove newlines in code blocks
    compressed=$(echo "$compressed" | awk '/^```/{flag=!flag; if(flag) printf " "; next} flag{printf "%s", $0; next} 1')
    
    # Truncate if too long
    local max_tokens
    max_tokens=${COMPRESS_THRESHOLD:-500}
    local estimated
    estimated=$(estimate_tokens "$compressed")
    
    if [[ $estimated -gt $max_tokens ]]; then
        local words
        words=$(echo "$compressed" | wc -w)
        local keep_words
        keep_words=$((max_tokens * words / estimated))
        compressed=$(echo "$compressed" | head -c "$keep_words")
    fi
    
    echo "$compressed"
}

# === BRAINX COMPRESS COMMAND ===
brainx_compress() {
    local text="${*:-}"
    
    if [[ -z "$text" ]]; then
        brainx_error "Usage: brainx-v2 compress <text>"
        return 1
    fi
    
    local compressed
    compressed=$(compress_tokens "$text")
    
    local original_tokens estimated_tokens
    original_tokens=$(estimate_tokens "$text")
    estimated_tokens=$(estimate_tokens "$compressed")
    
    echo -e "${BOLD}Compression Result${NC}"
    echo "======================"
    echo -e "Original tokens: $original_tokens"
    echo -e "Compressed tokens: $estimated_tokens"
    echo -e "Reduction: $((100 - estimated_tokens * 100 / original_tokens))%"
    echo ""
    echo "$compressed"
}
