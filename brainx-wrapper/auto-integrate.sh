#!/bin/bash
# BrainX V2 Auto-Integration for OpenClaw Agents
# This script auto-optimizes all LLM calls
# Source this file at the start of any agent script

# Load BrainX V2
BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"
source "$BRAINX_HOME/brainx-v2"

# === AUTO-OPTIMIZE SYSTEM PROMPT ===
# Compress AGENTS.md on load
optimize_agent_system_prompt() {
    local agent_dir="$1"
    local agents_md="$agent_dir/AGENTS.md"
    local optimized_md="$agent_dir/AGENTS.md.optimized"
    
    if [[ -f "$agents_md" ]]; then
        local compressed
        compressed=$(optimize_compress "$(cat "$agents_md")")
        echo "$compressed" > "$optimized_md"
        echo "[BrainX V2] System prompt compressed and saved to AGENTS.md.optimized"
    fi
}

# === OPTIMIZE BEFORE LLM CALL ===
# Call this before sending any message to the LLM
brainx_prepare_request() {
    local system_prompt="${1:-}"
    local user_message="${2:-}"
    local history="${3:-}"
    
    local opt_system=""
    local opt_user=""
    local token_count=0
    local cost_estimate=0
    
    # Compress system prompt if provided
    if [[ -n "$system_prompt" ]]; then
        opt_system=$(optimize_compress "$system_prompt")
        token_count=$((token_count + $(count_tokens "$opt_system")))
    fi
    
    # Compress user message if provided
    if [[ -n "$user_message" ]]; then
        opt_user=$(optimize_compress "$user_message")
        token_count=$((token_count + $(count_tokens "$opt_user")))
    fi
    
    # Calculate cost
    if [[ $token_count -gt 0 ]]; then
        cost_estimate=$(calculate_cost "$token_count")
    fi
    
    # Output optimized content
    cat <<EOF
{
  "system_prompt": "$opt_system",
  "user_message": "$opt_user",
  "history": "$history",
  "tokens": $token_count,
  "estimated_cost": $cost_estimate
}
EOF
}

# === WRAPPER FOR OPENCLAW CLI ===
# Prepend this to any openclaw command
brainx_openclaw() {
    if [[ -n "${1:-}" ]]; then
        local prompt="$1"
        local optimized
        optimized=$(optimize_compress "$prompt")
        # Replace prompt with optimized version
        shift
        echo "[BrainX V2] Compressed $(count_tokens "$prompt") → $(count_tokens "$optimized") tokens"
        /home/clawd/.openclaw/openclaw "$@" --prompt "$optimized"
    else
        /home/clawd/.openclaw/openclaw "$@"
    fi
}

# === OPTIMIZE SESSION HISTORY ===
# Reduce history to last N messages
brainx_truncate_history() {
    local history_file="$1"
    local max_messages="${2:-10}"
    local output_file="${3:-$history_file}"
    
    if [[ -f "$history_file" ]]; then
        truncate_to_messages "$history_file" "$max_messages" > "$output_file"
        echo "[BrainX V2] History truncated to last $max_messages messages"
    fi
}

# === DIAGNOSTIC ===
brainx_status() {
    echo "BrainX V2 Auto-Integration Status"
    echo "================================="
    echo "BRAINX_HOME: $BRAINX_HOME"
    echo "Version: $BRAINX_VERSION"
    echo ""
    echo "Available functions:"
    echo "  brainx_prepare_request <system> <user> <history>"
    echo "  optimize_agent_system_prompt <agent_dir>"
    echo "  brainx_truncate_history <file> [max_msgs]"
    echo "  brainx_openclaw <prompt> --args..."
}

# Auto-status on load
# brainx_status
