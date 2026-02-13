#!/bin/bash
# Tool Batching Functions
# lib/batcher.sh

set -euo pipefail

# === BATCH TOOLS ===
batch_tools() {
    local tools_json="$1"
    
    if [[ "${BATCH_ENABLED:-true}" != "true" ]]; then
        echo "$tools_json"
        return 0
    fi
    
    local min_tools=${BATCH_MIN_TOOLS:-2}
    local max_tools=${BATCH_MAX_TOOLS:-10}
    
    # Count tools
    local tool_count
    tool_count=$(echo "$tools_json" | jq 'length')
    
    if [[ $tool_count -lt $min_tools ]]; then
        echo "$tools_json"
        return 0
    fi
    
    # Create batched operations
    local batched="[]"
    
    for i in $(seq 0 $((tool_count - 1))); do
        local tool
        tool=$(echo "$tools_json" | jq -r ".[$i]")
        
        batched=$(echo "$batched" | jq --argjson tool "$tool" '. += [$tool]')
        
        # Output batch when full or last
        if [[ $((i % max_tools)) -eq $((max_tools - 1)) ]] || [[ $i -eq $((tool_count - 1)) ]]; then
            echo "BATCH: $(echo "$batched" | jq -c .)"
            batched="[]"
        fi
    done
}

# === BRAINX BATCH COMMAND ===
brainx_batch() {
    local tools_json="${1:-[]}"
    
    if [[ -z "$tools_json" ]]; then
        brainx_error "Usage: brainx-v2 batch <tool_calls_json>"
        return 1
    fi
    
    echo -e "${BOLD}Tool Batching${NC}"
    echo "==============="
    
    batch_tools "$tools_json"
}
