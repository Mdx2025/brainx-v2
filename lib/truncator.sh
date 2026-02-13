#!/bin/bash
# Smart Truncation - Remove redundant messages from chat history
# lib/truncator.sh

set -euo pipefail

# === CONFIG ===
MAX_HISTORY_MESSAGES="${MAX_HISTORY_MESSAGES:-20}"
MAX_HISTORY_TOKENS="${MAX_HISTORY_TOKENS:-100000}"
REMOVE_DUPLICATES="${REMOVE_DUPLICATES:-true}"
KEEP_SYSTEM="${KEEP_SYSTEM:-true}"
KEEP_LAST_N="${KEEP_LAST_N:-5}"

# === REMOVE DUPLICATE MESSAGES ===
remove_duplicate_messages() {
    local json="$1"
    
    if [[ "$REMOVE_DUPLICATES" != "true" ]]; then
        echo "$json"
        return 0
    fi
    
    if command -v jq &>/dev/null; then
        echo "$json" | jq 'unique_by(.content)'
    else
        echo "$json" | awk '!seen[$0]++'
    fi
}

# === TRUNCATE BY MESSAGE COUNT ===
truncate_by_count() {
    local json="$1"
    local max="${MAX_HISTORY_MESSAGES:-20}"
    
    if command -v jq &>/dev/null; then
        echo "$json" | jq ".[:$max]"
    else
        echo "$json" | head -n $max
    fi
}

# === TRUNCATE BY TOKEN COUNT ===
truncate_by_tokens() {
    local json="$1"
    local max_tokens="${MAX_HISTORY_TOKENS:-100000}"
    
    if ! command -v jq &>/dev/null; then
        truncate_by_count "$json" 10
        return 0
    fi
    
    local msg_count
    msg_count=$(echo "$json" | jq 'length')
    
    local current_tokens=0
    local result="[]"
    
    for ((i=msg_count-1; i>=0; i--)); do
        local msg
        msg=$(echo "$json" | jq ".[$i]")
        local msg_tokens
        msg_tokens=$(count_tokens "$msg")
        
        if [[ $((current_tokens + msg_tokens)) -lt $max_tokens ]]; then
            result=$(echo "$result" | jq ". + [$msg]")
            ((current_tokens += msg_tokens))
        else
            break
        fi
    done
    
    echo "$result" | jq 'reverse'
}

# === EXTRACT SYSTEM MESSAGE ===
extract_system() {
    local json="$1"
    
    if command -v jq &>/dev/null; then
        echo "$json" | jq '.[] | select(.role == "system")'
    else
        echo "$json" | grep -A 5 '"role": "system"'
    fi
}

# === BUILD TRUNCATED CONTEXT ===
build_truncated_context() {
    local system_msg="$1"
    local history="$2"
    
    local context="[]"
    
    if [[ -n "$system_msg" ]] && [[ "$KEEP_SYSTEM" == "true" ]]; then
        context=$(echo "$context" | jq ". + [$system_msg]")
    fi
    
    local truncated
    truncated=$(truncate_by_tokens "$history")
    context=$(echo "$context" | jq ". + $truncated")
    
    echo "$context"
}

# === SMART TRUNCATE ===
smart_truncate() {
    local messages="$1"
    
    messages=$(remove_duplicate_messages "$messages")
    messages=$(truncate_by_tokens "$messages")
    
    echo "$messages"
}

# === PRUNE OLD MESSAGES ===
prune_old() {
    local json="$1"
    local max_age="${1:-3600}"
    
    if ! command -v jq &>/dev/null; then
        echo "$json"
        return 0
    fi
    
    # Remove messages older than max_age seconds
    local now
    now=$(date +%s)
    
    echo "$json" | jq "[.[] | select(.timestamp > ($now - $max_age))]"
}

# === KEEP ONLY LATEST N EXCHANGES ===
keep_latest_exchanges() {
    local json="$1"
    local n="${KEEP_LAST_N:-5}"
    
    if ! command -v jq &>/dev/null; then
        truncate_by_count "$json" $((n * 2))
        return 0
    fi
    
    local total
    total=$(echo "$json" | jq 'length')
    
    if [[ $total -le $((n * 2)) ]]; then
        echo "$json"
        return 0
    fi
    
    # Keep last n user-assistant pairs
    echo "$json" | jq ".[-$((n * 2)):]"
}
