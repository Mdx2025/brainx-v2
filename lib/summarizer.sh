#!/bin/bash
# Context Summarization - Progressive message summarization
# lib/summarizer.sh
# Reduces history size by summarizing old messages

set -euo pipefail

# === CONFIG ===
SUMMARIZER_ENABLED="${SUMMARIZER_ENABLED:-true}"
SUMMARIZE_AFTER_N="${SUMMARIZE_AFTER_N:-10}"
SUMMARY_MAX_TOKENS="${SUMMARY_MAX_TOKENS:-300}"
KEEP_MESSAGES_AFTER_SUMMARY="${KEEP_MESSAGES_AFTER_SUMMARY:-5}"

# === TOKEN ESTIMATION ===
estimate_tokens() {
    local text="$1"
    # Rough estimate: ~4 characters per token
    echo $(( ${#text} / 4 ))
}

# === EXTRACT KEY FACTS ===
extract_key_facts() {
    local messages="$1"
    
    # Extract lines that look like facts
    echo "$messages" | grep -E '^\s*[-•*]' | head -20
    echo "$messages" | grep -iE '(decided|concluded|result|error|success|failed|completed|created|deleted|updated)' | head -10
}

# === CREATE SUMMARY ===
create_summary() {
    local messages="$1"
    local session_id="${2:-unknown}"
    
    local fact_count decision_count
    fact_count=$(echo "$messages" | grep -cE '^\s*[-•*]' || true)
    decision_count=$(echo "$messages" | grep -ciE '(decided|decision|concluded)' || true)
    
    local summary
    summary=$(cat <<EOF
## Session Summary [$session_id]
- Messages summarized: $(echo "$messages" | grep -c '^\[' || echo "0")
- Key facts extracted: $fact_count
- Decisions recorded: $decision_count

### Key Points
$(extract_key_facts "$messages")

[Session continues...]
EOF
)
    
    # Compress summary if too long
    local tokens
    tokens=$(estimate_tokens "$summary")
    
    if [[ $tokens -gt $SUMMARY_MAX_TOKENS ]]; then
        summary=$(echo "$summary" | head -c $((SUMMARY_MAX_TOKENS * 4)))
        summary="$summary

[Summary truncated due to length]"
    fi
    
    echo "$summary"
}

# === PROGRESSIVE SUMMARIZATION ===
summarize_progressive() {
    local messages_json="$1"
    local session_id="${2:-unknown}"
    
    if [[ "$SUMMARIZER_ENABLED" != "true" ]]; then
        echo "$messages_json"
        return 0
    fi
    
    local msg_count
    msg_count=$(echo "$messages_json" | jq 'length')
    
    # Not enough messages to summarize
    if [[ $msg_count -le $SUMMARIZE_AFTER_N ]]; then
        echo "$messages_json"
        return 0
    fi
    
    # Calculate split point
    local to_summarize_count=$((msg_count - KEEP_MESSAGES_AFTER_SUMMARY))
    
    # Messages to summarize (older ones)
    local to_summarize
    to_summarize=$(echo "$messages_json" | jq ".[:$to_summarize_count]")
    
    # Messages to keep (recent ones)
    local to_keep
    to_keep=$(echo "$messages_json" | jq ".[-$KEEP_MESSAGES_AFTER_SUMMARY:]")
    
    # Convert to text for summarization
    local messages_text
    messages_text=$(echo "$to_summarize" | jq -r '.[] | "[\(.role // "unknown")]: \(.content // "")"')
    
    # Create summary
    local summary
    summary=$(create_summary "$messages_text" "$session_id")
    
    # Build result: summary as system message + recent messages
    local summary_json
    summary_json=$(jq -n --arg content "$summary" --arg sess "$session_id" '{
        role: "system",
        content: $content,
        name: "session_summary",
        session_id: $sess
    }')
    
    # Combine summary + recent messages
    echo "[$summary_json]" | jq --argjson keep "$to_keep" '. + $keep'
}

# === SMART CONTEXT WINDOW ===
manage_context_window() {
    local full_context="$1"
    local max_tokens="${2:-100000}"
    
    local total_tokens
    total_tokens=$(estimate_tokens "$full_context")
    
    if [[ $total_tokens -le $max_tokens ]]; then
        echo "$full_context"
        return 0
    fi
    
    # Need to reduce context
    local lines
    lines=$(echo "$full_context" | wc -l)
    local keep_lines=$((lines * max_tokens / total_tokens))
    
    # Keep first 20% (system/setup), summarize middle, keep last 30% (recent)
    local head_lines=$((keep_lines / 5))
    local tail_lines=$((keep_lines * 3 / 10))
    local middle_start=$((head_lines + 1))
    local middle_end=$((lines - tail_lines))
    
    local head_context tail_context middle_context
    head_context=$(echo "$full_context" | head -n "$head_lines")
    tail_context=$(echo "$full_context" | tail -n "$tail_lines")
    middle_context=$(echo "$full_context" | sed -n "${middle_start},${middle_end}p")
    
    # Summarize middle section
    local middle_summary
    middle_summary=$(create_summary "$middle_context" "middle_section")
    
    cat <<EOF
$head_context

[... $((middle_end - middle_start)) lines summarized ...]
$middle_summary

$tail_context
EOF
}

# === AGGRESSIVE SUMMARIZATION FOR COST CONTROL ===
aggressive_summarize() {
    local text="$1"
    local target_tokens="$2"
    
    local current_tokens
    current_tokens=$(estimate_tokens "$text")
    
    while [[ $current_tokens -gt $target_tokens ]]; do
        # Remove least important lines (heuristic)
        text=$(echo "$text" | grep -vE '^\s*$' | grep -vE '^[[:space:]]*#' | head -n -5)
        
        # Try to extract key points only
        local key_points
        key_points=$(echo "$text" | grep -E '(important|critical|error|success|decided|conclusion|result)' | head -10)
        
        if [[ -n "$key_points" ]]; then
            text="$key_points

[Content aggressively summarized for cost control]"
        fi
        
        current_tokens=$(estimate_tokens "$text")
        
        # Prevent infinite loop
        if [[ ${#text} -lt 100 ]]; then
            break
        fi
    done
    
    echo "$text"
}

# === BRAINX SUMMARIZE COMMAND ===
brainx_summarize() {
    local file="${1:-}"
    
    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        brainx_error "Usage: brainx-v2 summarize <messages.json>"
        return 1
    fi
    
    echo -e "${BOLD}Progressive Summarization${NC}"
    echo "=========================="
    
    local content
    content=$(cat "$file")
    
    local original_tokens
    original_tokens=$(estimate_tokens "$content")
    echo "Original tokens: $original_tokens"
    
    local summarized
    summarized=$(summarize_progressive "$content" "cli_session")
    
    local new_tokens
    new_tokens=$(estimate_tokens "$summarized")
    echo "After summarization: $new_tokens"
    echo "Reduction: $((100 - new_tokens * 100 / original_tokens))%"
    echo ""
    
    echo "$summarized" | jq .
}

# === SESSION CONTEXT MANAGER ===
# Called by agent wrapper to maintain context window
brainx_manage_session_context() {
    local session_file="$1"
    
    if [[ ! -f "$session_file" ]]; then
        return 0
    fi
    
    local content
    content=$(cat "$session_file")
    
    local token_count
    token_count=$(estimate_tokens "$content")
    
    # If over threshold, summarize
    if [[ $token_count -gt $MAX_HISTORY_TOKENS ]]; then
        brainx_log INFO "Session context over threshold ($token_count > $MAX_HISTORY_TOKENS), summarizing..."
        
        local summarized
        summarized=$(summarize_progressive "$content")
        
        # Backup original
        cp "$session_file" "${session_file}.$(date +%s).bak"
        
        # Write summarized version
        echo "$summarized" > "$session_file"
        
        local new_tokens
        new_tokens=$(estimate_tokens "$summarized")
        brainx_log SUCCESS "Context reduced from $token_count to $new_tokens tokens"
    fi
}
