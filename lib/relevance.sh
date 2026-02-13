#!/bin/bash
# Relevance Scoring - Calculate relevance between query and context
# lib/relevance.sh

set -euo pipefail

# === CONFIG ===
RELEVANCE_THRESHOLD="${RELEVANCE_THRESHOLD:-70}"
RELEVANCE_WEIGHT_KEYWORD="${RELEVANCE_WEIGHT_KEYWORD:-0.3}"
RELEVANCE_WEIGHT_SEMANTIC="${RELEVANCE_WEIGHT_SEMANTIC:-0.5}"
RELEVANCE_WEIGHT_STRUCTURE="${RELEVANCE_WEIGHT_STRUCTURE:-0.2}"

# === KEYWORD MATCH ===
keyword_match_score() {
    local query="$1"
    local context="$2"
    
    local query_words=0
    local matched=0
    
    for word in $query; do
        ((query_words++))
        if echo "$context" | grep -qi "$word"; then
            ((matched++))
        fi
    done
    
    [[ $query_words -eq 0 ]] && echo "0" && return 0
    echo $(( matched * 100 / query_words ))
}

# === SEMANTIC SIMILARITY ===
semantic_score() {
    local query="$1"
    local context="$2"
    
    local q_norm=$(echo "$query" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]')
    local c_norm=$(echo "$context" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]')
    
    local q_words=$(echo "$q_norm" | tr ' ' '\n' | sort -u)
    local c_words=$(echo "$c_norm" | tr ' ' '\n' | sort -u)
    
    local common=$(comm -12 <(echo "$q_words") <(echo "$c_words") | wc -l)
    local total=$(echo "$q_words" | wc -l)
    
    [[ $total -eq 0 ]] && echo "0" && return 0
    echo $(( common * 100 / total ))
}

# === STRUCTURE MATCH ===
structure_score() {
    local query="$1"
    local context="$2"
    
    local query_struct=$(echo "$query" | grep -cE "^[0-9]+\.|[A-Z][a-z]+:")
    local context_struct=$(echo "$context" | grep -cE "^[0-9]+\.|[A-Z][a-z]+:")
    
    [[ $query_struct -eq 0 ]] && echo "50" && return 0
    
    local diff=$((query_struct - context_struct))
    [[ $diff -lt 0 ]] && diff=$((-diff))
    
    local score=$((100 - diff * 10))
    [[ $score -lt 0 ]] && score=0
    
    echo "$score"
}

# === LENGTH PENALTY ===
length_penalty() {
    local context="$1"
    local optimal_length="${OPTIMAL_LENGTH:-500}"
    local length=${#context}
    
    if [[ $length -lt $optimal_length ]]; then
        echo "100"
        return 0
    fi
    
    local penalty=$((100 - (length - optimal_length) / 10))
    [[ $penalty -lt 50 ]] && penalty=50
    echo "$penalty"
}

# === MAIN RELEVANCE CALCULATION ===
calculate_relevance() {
    local query="$1"
    local context="$2"
    
    local keyword semantic structure length
    
    keyword=$(keyword_match_score "$query" "$context")
    semantic=$(semantic_score "$query" "$context")
    structure=$(structure_score "$query" "$context")
    length=$(length_penalty "$context")
    
    local relevance
    relevance=$(echo "scale=2; $keyword * $RELEVANCE_WEIGHT_KEYWORD + $semantic * $RELEVANCE_WEIGHT_SEMANTIC + $structure * $RELEVANCE_WEIGHT_STRUCTURE" | bc)
    
    echo "${relevance%.*}"
}

# === RELEVANCE VERDICT ===
relevance_verdict() {
    local score="$1"
    
    if [[ $score -ge 80 ]]; then
        echo "HIGH"
    elif [[ $score -ge 50 ]]; then
        echo "MEDIUM"
    else
        echo "LOW"
    fi
}

# === IS RELEVANT? ===
is_relevant() {
    local query="$1"
    local context="$2"
    
    local score
    score=$(calculate_relevance "$query" "$context")
    
    [[ $score -ge $RELEVANCE_THRESHOLD ]]
}

# === FILTER RELEVANT ===
filter_relevant() {
    local query="$1"
    shift
    local items=("$@")
    
    local relevant=()
    
    for item in "${items[@]}"; do
        if is_relevant "$query" "$item"; then
            relevant+=("$item")
        fi
    done
    
    printf '%s\n' "${relevant[@]}"
}
