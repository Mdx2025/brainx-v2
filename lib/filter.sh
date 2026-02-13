#!/bin/bash
# Relevance Filtering Functions
# lib/filter.sh

set -euo pipefail

# === FILTER BY THRESHOLD ===
filter_threshold() {
    local threshold="${1:-70}"
    shift
    local results=("$@")
    
    local filtered=()
    
    for result in "${results[@]}"; do
        # Skip empty results
        [[ -z "$result" ]] && continue
        
        local score
        score=$(echo "$result" | cut -d: -f1)
        
        # Validate score is numeric
        if [[ "$score" =~ ^[0-9]+$ ]] && [[ $score -ge $threshold ]]; then
            filtered+=("$result")
        fi
    done
    
    printf '%s\n' "${filtered[@]}"
}

# === SORT BY SCORE ===
sort_by_score() {
    local results=("$@")
    
    printf '%s\n' "${results[@]}" | sort -t: -k1 -rn
}

# === BRAINX FILTER COMMAND ===
brainx_filter() {
    local query="${1:-}"
    
    if [[ -z "$query" ]]; then
        brainx_error "Usage: brainx-v2 filter <query>"
        return 1
    fi
    
    echo -e "${BOLD}Filtered Results (threshold: $SCORE_THRESHOLD)${NC}"
    echo "============================================"
    
    local results=()
    
    # Get search results
    while IFS= read -r line; do
        results+=("$line")
    done < <(storage_search "$query")
    
    # Filter and sort
    filter_threshold "$SCORE_THRESHOLD" "${results[@]}" | sort_by_score
}
