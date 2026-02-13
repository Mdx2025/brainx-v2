#!/bin/bash
# Relevance Scoring Functions
# lib/scoring.sh

set -euo pipefail

# === SCORE RELEVANCE ===
score_relevance() {
    local query="$1"
    local content="$2"
    local context="${3:-}"
    local tags="${4:-}"
    
    local score=0
    
    # Content weight (default 0.6)
    local content_score
    content_score=$(calculate_content_score "$query" "$content")
    score=$((score + content_score * SCORE_WEIGHT_CONTENT * 100 / 1))
    
    # Context weight (default 0.3)
    if [[ -n "$context" ]]; then
        local context_score
        context_score=$(calculate_content_score "$query" "$context")
        score=$((score + context_score * SCORE_WEIGHT_CONTEXT * 100 / 1))
    fi
    
    # Tags weight (default 0.1)
    if [[ -n "$tags" ]]; then
        local tags_score
        tags_score=$(calculate_tags_score "$query" "$tags")
        score=$((score + tags_score * SCORE_WEIGHT_TAGS * 100 / 1))
    fi
    
    # Normalize to 0-100
    score=$((score > 100 ? 100 : score))
    score=$((score < 0 ? 0 : score))
    
    echo "$score"
}

# === CALCULATE CONTENT SCORE ===
calculate_content_score() {
    local query="$1"
    local content="$2"
    local score=0
    
    # Tokenize query
    local query_words
    query_words=$(echo "$query" | tr '[:upper:]' '[:lower:]' | tr ' ' '\n' | grep -v '^$')
    
    for word in $query_words; do
        local matches
        matches=$(echo "$content" | grep -oi "$word" | wc -l)
        
        # Exact word match in content (case insensitive)
        if echo "$content" | grep -qi "\\b$word\\b"; then
            ((matches++))
        fi
        
        score=$((score + matches * 10))
    done
    
    # Normalize
    if [[ $score -gt 100 ]]; then
        score=100
    fi
    
    echo "$score"
}

# === CALCULATE TAGS SCORE ===
calculate_tags_score() {
    local query="$1"
    local tags="$2"
    local score=0
    
    # Tokenize query
    local query_words
    query_words=$(echo "$query" | tr '[:upper:]' '[:lower:]' | tr ' ' '\n' | grep -v '^$')
    
    for word in $query_words; do
        if echo "$tags" | grep -qi "$word"; then
            score=$((score + 20))
        fi
    done
    
    echo "$score"
}

# === SCORE MEMORY ===
brainx_score() {
    local query="${1:-}"
    local memory_id="${2:-}"
    
    if [[ -z "$query" ]]; then
        brainx_error "Usage: brainx-v2 score <query> [memory_id]"
        return 1
    fi
    
    if [[ -n "$memory_id" ]]; then
        # Score specific memory
        local memory_json
        memory_json=$(storage_get "$memory_id" 2>/dev/null || echo "{}")
        
        local content context tags
        content=$(echo "$memory_json" | jq -r '.content // empty')
        context=$(echo "$memory_json" | jq -r '.context // empty')
        
        local score
        score=$(score_relevance "$query" "$content" "$context")
        
        echo -e "Memory: $memory_id"
        echo -e "Score: ${GREEN}$score/100${NC}"
    else
        # Score all memories against query
        echo -e "${BOLD}Relevance Scores for Query: $query${NC}"
        echo "========================================"
        
        storage_search "$query" | while read -r id tier; do
            local memory_json
            memory_json=$(storage_get "$id" 2>/dev/null)
            
            local content context
            content=$(echo "$memory_json" | jq -r '.content // empty')
            context=$(echo "$memory_json" | jq -r '.context // empty')
            
            local score
            score=$(score_relevance "$query" "$content" "$context")
            
            if [[ $score -ge $SCORE_THRESHOLD ]]; then
                echo -e "${GREEN}[$score] $id${NC}"
            fi
        done
    fi
}
