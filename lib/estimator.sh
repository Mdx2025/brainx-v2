#!/bin/bash
# Token Estimation Functions
# lib/estimator.sh

set -euo pipefail

# === ESTIMATE TOKENS ===
estimate_tokens() {
    local text="$1"
    
    # Rough estimate: 4 characters per token on average
    local char_count
    char_count=${#text}
    
    local tokens
    tokens=$((char_count / 4))
    
    echo "$tokens"
}

# === ESTIMATE JSON TOKENS ===
estimate_json_tokens() {
    local json="$1"
    
    # JSON is typically more token-intensive
    local char_count
    char_count=${#json}
    
    local tokens
    tokens=$((char_count / 3))
    
    echo "$tokens"
}
