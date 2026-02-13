#!/bin/bash
# Metrics Tracking Module
# lib/metrics.sh

set -euo pipefail

# === METRICS DATABASE ===
METRICS_DB="${BRAINX_HOME}/.metrics.json"

# === METRICS LOCK ===
METRICS_LOCK="${BRAINX_HOME}/.metrics.lock"

# === INITIALIZE METRICS ===
metrics_init() {
    mkdir -p "$(dirname "$METRICS_DB")"
    if [[ ! -f "$METRICS_DB" ]]; then
        echo '{"agents": {}, "sessions": [], "daily": {}}' > "$METRICS_DB"
    fi
}

# === ACQUIRE LOCK ===
metrics_lock() {
    local max_attempts=10
    local attempt=0
    while [[ -f "$METRICS_LOCK" ]] && [[ $attempt -lt $max_attempts ]]; do
        sleep 0.1
        ((attempt++))
    done
    touch "$METRICS_LOCK"
}

# === RELEASE LOCK ===
metrics_unlock() {
    rm -f "$METRICS_LOCK"
}

# === TRACK SESSION START ===
metrics_session_start() {
    local agent="$1"
    local context="$2"
    
    metrics_lock
    trap 'metrics_unlock' EXIT
    
    local timestamp
    timestamp=$(date -Iseconds)
    local session_id
    session_id=$(brainx_generate_id)
    
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg agent "$agent" \
       --arg context "$context" \
       --arg session_id "$session_id" \
       --arg timestamp "$timestamp" \
       '.sessions += [{
           "id": $session_id,
           "agent": $agent,
           "context": $context,
           "start": $timestamp,
           "end": null,
           "tokens_in": 0,
           "tokens_out": 0,
           "cost": 0,
           "messages": 0
       }] |
       .agents[$agent] = (.agents[$agent] // {
           "total_sessions": 0,
           "total_tokens_in": 0,
           "total_tokens_out": 0,
           "total_cost": 0,
           "total_time": 0
       }) |
       .agents[$agent].total_sessions += 1' \
       "$METRICS_DB" > "$temp_file" && mv "$temp_file" "$METRICS_DB"
    
    metrics_unlock
    trap - EXIT
    
    echo "$session_id"
}

# === TRACK TOKENS ===
metrics_track_tokens() {
    local session_id="$1"
    local tokens_in="$2"
    local tokens_out="$3"
    local cost="$4"
    
    # Cost per token (aproximate, configurable)
    local cost_per_token="${BRAINX_COST_PER_TOKEN:-0.00001}"
    local calculated_cost
    calculated_cost=$(echo "scale=6; ($tokens_in + $tokens_out) * $cost_per_token" | bc)
    
    metrics_lock
    trap 'metrics_unlock' EXIT
    
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg session_id "$session_id" \
       --argjson tokens_in "$tokens_in" \
       --argjson tokens_out "$tokens_out" \
       --argjson cost "$calculated_cost" \
       '.sessions |= map(
           if .id == $session_id then
               .tokens_in += $tokens_in |
               .tokens_out += $tokens_out |
               .cost += $cost |
               .messages += 1
           else
               .
           end
       )' "$METRICS_DB" > "$temp_file" && mv "$temp_file" "$METRICS_DB"
    
    # Update agent totals
    local agent
    agent=$(jq -r --arg session_id "$session_id" '.sessions[] | select(.id == $session_id) | .agent' "$METRICS_DB")
    
    jq --arg agent "$agent" \
       --argjson tokens_in "$tokens_in" \
       --argjson tokens_out "$tokens_out" \
       --argjson cost "$calculated_cost" \
       '.agents[$agent].total_tokens_in += $tokens_in |
        .agents[$agent].total_tokens_out += $tokens_out |
        .agents[$agent].total_cost += $cost' \
       "$METRICS_DB" > "$temp_file" && mv "$temp_file" "$METRICS_DB"
    
    metrics_unlock
    trap - EXIT
}

# === TRACK SESSION END ===
metrics_session_end() {
    local session_id="$1"
    local summary="$2"
    
    metrics_lock
    trap 'metrics_unlock' EXIT
    
    local temp_file
    temp_file=$(mktemp)
    local end_time
    end_time=$(date -Iseconds)
    
    # Calculate duration
    local start_time
    start_time=$(jq -r --arg session_id "$session_id" '.sessions[] | select(.id == $session_id) | .start' "$METRICS_DB")
    local duration
    duration=$(($(date +%s) - $(date -d "$start_time" +%s)))
    
    jq --arg session_id "$session_id" \
       --arg summary "$summary" \
       --arg end_time "$end_time" \
       --argjson duration "$duration" \
       '.sessions |= map(
           if .id == $session_id then
               .summary = $summary |
               .end = $end_time |
               .duration = $duration
           else
               .
           end
       )' "$METRICS_DB" > "$temp_file" && mv "$temp_file" "$METRICS_DB"
    
    # Update agent total time
    local agent
    agent=$(jq -r --arg session_id "$session_id" '.sessions[] | select(.id == $session_id) | .agent' "$METRICS_DB")
    
    jq --arg agent "$agent" \
       --argjson duration "$duration" \
       '.agents[$agent].total_time += $duration' \
       "$METRICS_DB" > "$temp_file" && mv "$temp_file" "$METRICS_DB"
    
    metrics_unlock
    trap - EXIT
}

# === GET AGENT METRICS ===
metrics_get_agent() {
    local agent="$1"
    jq -c ".agents[$agent] // empty" "$METRICS_DB"
}

# === GET ALL METRICS ===
metrics_get_all() {
    jq '.' "$METRICS_DB"
}

# === GET SESSION METRICS ===
metrics_get_session() {
    local session_id="$1"
    jq -c ".sessions[] | select(.id == \"$session_id\")" "$METRICS_DB"
}

# === PRINT METRICS REPORT ===
metrics_report() {
    echo -e "${BOLD}BrainX Metrics Report${NC}"
    echo "========================"
    echo ""
    
    # Daily summary
    local today
    today=$(date +%Y-%m-%d)
    echo -e "${CYAN}Today: $today${NC}"
    echo ""
    
    # Agent totals
    echo -e "${GREEN}Agent Statistics:${NC}"
    jq -r '.agents | to_entries[] | 
        "  \(.key): \(.value.total_sessions) sessions, " +
        "\(.value.total_tokens_in + .value.total_tokens_out) tokens, " +
        "$\(.value.total_cost) cost, " +
        "\(.value.total_time)s time"' "$METRICS_DB"
    
    echo ""
    echo -e "${YELLOW}Recent Sessions:${NC}"
    jq -r '.sessions[-10:] | reverse[] |
        "  \(.id[0:8]): \(.agent) - \(.messages // 0) msgs, " +
        "\(.tokens_in + .tokens_out) tokens, $\(.cost)"' "$METRICS_DB"
    
    echo ""
    echo -e "${BLUE}Total System Stats:${NC}"
    local total_tokens
    total_tokens=$(jq '[.sessions[].tokens_in + .sessions[].tokens_out] | add' "$METRICS_DB")
    local total_cost
    total_cost=$(jq '[.sessions[].cost] | add' "$METRICS_DB")
    echo "  Total Tokens: ${total_tokens:-0}"
    echo "  Total Cost: $${total_cost:-0}"
}

# === EXPORT METRICS TO CSV ===
metrics_export_csv() {
    local output_file="${1:-metrics.csv}"
    jq -r '.sessions[] |
        "\(.id),\(.agent),\(.start),\(.end),\(.duration),\(.tokens_in),\(.tokens_out),\(.cost),\(.messages)"' \
        "$METRICS_DB" > "$output_file"
    echo "Exported to $output_file"
}

# === METRICS CLEANUP (keep last N sessions) ===
metrics_cleanup() {
    local keep="${1:-100}"
    local temp_file
    temp_file=$(mktemp)
    
    jq --argjson keep "$keep" \
       '.sessions = (.sessions | sort_by(.start) | take_last($keep))' \
       "$METRICS_DB" > "$temp_file" && mv "$temp_file" "$METRICS_DB"
    
    echo "Cleaned up, keeping last $keep sessions"
}
