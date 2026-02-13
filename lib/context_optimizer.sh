#!/bin/bash
# Context Optimizer Module
# Filters and optimizes context before sending to LLM
# lib/context_optimizer.sh

set -euo pipefail

# === CONFIGURATION ===
BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"
CONTEXT_OPTIMIZER_DIR="$BRAINX_HOME/.context_optimizer"

# Token Budgets (in tokens, approximate)
DEFAULT_TOKEN_BUDGET=4000
MAX_TOKEN_BUDGET=16000  # Safe margin for 32K context models

# Token Allocations by Type
declare -A CONTEXT_TOKEN_BUDGETS=(
    ["MEMORY_HOT"]=500
    ["MEMORY_WARM"]=1000
    ["MEMORY_COLD"]=500
    ["RAG_RESULTS"]=1500
    ["RECENT_HISTORY"]=500
    ["AGENT_CONTEXT"]=500
    ["SYSTEM_PROMPT"]=500
)

# Relevance Thresholds
MIN_RELEVANCE_SCORE=0.5
MAX_CONTEXT_ENTRIES=10

# === INITIALIZATION ===
context_optimizer_init() {
    mkdir -p "$CONTEXT_OPTIMIZER_DIR"
}

# === ESTIMATE TOKENS ===
_estimate_tokens() {
    local text="$1"
    # Rough estimate: 1 token ≈ 4 characters for English-like text
    echo $(( $(echo "$text" | wc -c) / 4 ))
}

# === CALCULATE CONTEXT BUDGET ===
calculate_context_budget() {
    local model_context_size="${1:-32000}"
    local system_prompt_tokens="${2:-500}"

    # Calculate available budget for context
    local budget=$((model_context_size - system_prompt_tokens - 2000))  # 2K buffer for response
    [[ $budget -gt $MAX_TOKEN_BUDGET ]] && budget=$MAX_TOKEN_BUDGET
    [[ $budget -lt $DEFAULT_TOKEN_BUDGET ]] && budget=$DEFAULT_TOKEN_BUDGET

    echo "$budget"
}

# === FILTER CONTEXT BY RELEVANCE ===
filter_context_by_relevance() {
    local context_json="$1"
    local query="$2"
    local min_score="${3:-$MIN_RELEVANCE_SCORE}"
    local max_entries="${4:-$MAX_CONTEXT_ENTRIES}"

    # Filter entries below threshold
    local filtered="[]"
    local count=0

    while IFS= read -r entry; do
        local score
        score=$(echo "$entry" | jq -r '.relevance_score // 0.5')

        if (( $(echo "$score >= $min_score" | bc -l) )); then
            [[ $count -ge $max_entries ]] && break

            filtered=$(echo "$filtered" | jq --argjson e "$entry" '. + [$e]')
            ((count++))
        fi
    done < <(echo "$context_json" | jq -c '.[]')

    echo "$filtered"
}

# === COMPRESS CONTEXT ===
compress_context() {
    local context_text="$1"
    local target_tokens="${2:-$DEFAULT_TOKEN_BUDGET}"

    local current_tokens
    current_tokens=$(_estimate_tokens "$context_text")

    if [[ $current_tokens -le $target_tokens ]]; then
        echo "$context_text"
        return 0
    fi

    # Load compressor module if available
    if [[ -f "$BRAINX_HOME/lib/compressor.sh" ]]; then
        source "$BRAINX_HOME/lib/compressor.sh"

        local compressed
        compressed=$(brainx_compress_text "$context_text" "$target_tokens")
        echo "$compressed"
    else
        # Fallback: simple truncation
        echo "$context_text" | head -c $((target_tokens * 4))
    fi
}

# === BUILD OPTIMIZED CONTEXT ===
build_optimized_context() {
    local query="$1"
    local agent_context="${2:-}"
    local recent_history="${3:-}"
    local memory_data="${4:-}"
    local model_context_size="${5:-32000}"

    # Step 1: Calculate budget
    local budget
    budget=$(calculate_context_budget "$model_context_size")

    # Step 2: Build context with priorities
    local context_parts="[]"

    # Priority 1: Agent context (system prompt + agent-specific context)
    local agent_tokens="${CONTEXT_TOKEN_BUDGETS[AGENT_CONTEXT]}"
    local compressed_agent
    compressed_agent=$(compress_context "$agent_context" "$agent_tokens")
    context_parts=$(echo "$context_parts" | jq --arg content "$compressed_agent" \
                                        --arg type "agent_context" \
                                        --argjson tokens "$(_estimate_tokens "$compressed_agent")" \
                                        '. += [{"type": $type, "content": $content, "tokens": $tokens}]')

    # Priority 2: Recent history (last few messages)
    local history_tokens="${CONTEXT_TOKEN_BUDGETS[RECENT_HISTORY]}"
    local compressed_history
    compressed_history=$(compress_context "$recent_history" "$history_tokens")
    context_parts=$(echo "$context_parts" | jq --arg content "$compressed_history" \
                                        --arg type "recent_history" \
                                        --argjson tokens "$(_estimate_tokens "$compressed_history")" \
                                        '. += [{"type": $type, "content": $content, "tokens": $tokens}]')

    # Priority 3: RAG results (if available and relevant)
    if [[ -f "$BRAINX_HOME/lib/relevance.sh" ]] && [[ -n "$memory_data" ]]; then
        source "$BRAINX_HOME/lib/relevance.sh"

        local rag_budget="${CONTEXT_TOKEN_BUDGETS[RAG_RESULTS]}"
        local scored_memory

        # Score memory entries
        scored_memory=$(brainx_score_relevance "$memory_data" "$query")

        # Filter by relevance
        local filtered_memory
        filtered_memory=$(filter_context_by_relevance "$scored_memory" "$query" "$MIN_RELEVANCE_SCORE" 5)

        # Compress to fit budget
        local memory_text
        memory_text=$(echo "$filtered_memory" | jq -r '.[].content' | head -c $((rag_budget * 4)))

        local compressed_memory
        compressed_memory=$(compress_context "$memory_text" "$rag_budget")

        context_parts=$(echo "$context_parts" | jq --arg content "$compressed_memory" \
                                            --arg type "rag_results" \
                                            --argjson tokens "$(_estimate_tokens "$compressed_memory")" \
                                            '. += [{"type": $type, "content": $content, "tokens": $tokens}]')
    fi

    # Step 3: Calculate total and trim if over budget
    local total_tokens
    total_tokens=$(echo "$context_parts" | jq '[.[].tokens] | add')

    if [[ $total_tokens -gt $budget ]]; then
        # Trim from lowest priority
        context_parts=$(trim_context_to_budget "$context_parts" "$budget")
    fi

    # Step 4: Return assembled context
    echo "$context_parts" | jq -s '.[0]'
}

# === TRIM CONTEXT TO BUDGET ===
trim_context_to_budget() {
    local context_parts="$1"
    local budget="$2"

    local current_tokens
    current_tokens=$(echo "$context_parts" | jq '[.[].tokens] | add')

    if [[ $current_tokens -le $budget ]]; then
        echo "$context_parts"
        return 0
    fi

    # Remove lowest priority parts first (keep agent_context, recent_history)
    local trimmed="$context_parts"

    # Try removing RAG first
    if [[ $(echo "$trimmed" | jq 'map(select(.type == "rag_results")) | length') -gt 0 ]]; then
        trimmed=$(echo "$trimmed" | jq 'map(select(.type != "rag_results"))')
        current_tokens=$(echo "$trimmed" | jq '[.[].tokens] | add')

        if [[ $current_tokens -le $budget ]]; then
            echo "$trimmed"
            return 0
        fi
    fi

    # Reduce recent_history
    trimmed=$(echo "$trimmed" | jq 'map(if .type == "recent_history" then .content |= .[0:$((budget / 8))] else . end)')
    trimmed=$(echo "$trimmed" | jq 'map(.tokens = (_estimate_tokens(.content) // 0))')

    echo "$trimmed"
}

# === GET CONTEXT SUMMARY ===
get_context_summary() {
    local context_json="$1"

    echo "=== Context Summary ==="
    echo "$context_json" | jq -r '
        "Total Parts: \([. | length])",
        "Total Tokens: \([.[].tokens] | add)",
        "",
        "By Type:",
        (. | group_by(.type) | .[] | {
            type: .[0].type,
            parts: length,
            tokens: (map(.tokens) | add)
        } | "  - \(.type): \(.parts) parts, \(.tokens) tokens")
    '
}

# === ANALYZE CONTEXT QUALITY ===
analyze_context_quality() {
    local query="$1"
    local context_json="$2"

    local total_parts
    total_parts=$(echo "$context_json" | jq '. | length')

    local total_tokens
    total_tokens=$(echo "$context_json" | jq '[.[].tokens] | add')

    local has_rag
    has_rag=$(echo "$context_json" | jq 'map(select(.type == "rag_results")) | length')

    local has_history
    has_history=$(echo "$context_json" | jq 'map(select(.type == "recent_history")) | length')

    local has_agent_context
    has_agent_context=$(echo "$context_json" | jq 'map(select(.type == "agent_context")) | length')

    local score=0

    # Has agent context
    [[ $has_agent_context -gt 0 ]] && ((score+=25))

    # Has recent history
    [[ $has_history -gt 0 ]] && ((score+=25))

    # Has RAG results (if query needs memory)
    if [[ -n "$query" ]]; then
        [[ $has_rag -gt 0 ]] && ((score+=25))
    fi

    # Token usage within budget
    [[ $total_tokens -le $DEFAULT_TOKEN_BUDGET ]] && ((score+=25))

    echo "$score"
}

# === EXPORT FUNCTIONS ===
export -f _estimate_tokens
export -f calculate_context_budget
export -f filter_context_by_relevance
export -f compress_context
export -f build_optimized_context
export -f trim_context_to_budget
export -f get_context_summary
export -f analyze_context_quality

# === INIT ON LOAD ===
context_optimizer_init
