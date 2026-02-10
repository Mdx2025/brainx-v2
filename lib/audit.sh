#!/bin/bash
# Audit Log Module
# lib/audit.sh

set -euo pipefail

# === AUDIT LOG DIRECTORY ===
AUDIT_DIR="$BRAINX_HOME/.audit"
AUDIT_LOG="$AUDIT_DIR/log.jsonl"
AUDIT_INDEX="$AUDIT_DIR/index.json"

# === INITIALIZE ===
audit_init() {
    mkdir -p "$AUDIT_DIR"
    mkdir -p "$AUDIT_DIR/queries"
    mkdir -p "$AUDIT_DIR/access"
    [[ -f "$AUDIT_LOG" ]] || touch "$AUDIT_LOG"
    [[ -f "$AUDIT_INDEX" ]] || echo '{"by_agent": {}, "by_date": {}, "by_type": {}}' > "$AUDIT_INDEX"
}

# === LOG QUERY ===
audit_query() {
    local agent="$1"
    local query="$2"
    local result_count="$3"
    local duration_ms="$4"
    
    local entry_id
    entry_id=$(brainx_generate_id)
    local timestamp
    timestamp=$(date -Iseconds)
    
    local entry
    entry=$(jq -n --arg id "$entry_id" \
                     --arg agent "$agent" \
                     --arg query "$query" \
                     --argjson count "$result_count" \
                     --argjson duration "$duration_ms" \
                     --arg timestamp "$timestamp" \
                     --arg type "query" \
                     '{"id": $id, "type": $type, "agent": $agent, "query": $query, "result_count": $count, "duration_ms": $duration, "timestamp": $timestamp}')
    
    echo "$entry" >> "$AUDIT_LOG"
    audit_index_entry "$entry_id" "query" "$agent" "$timestamp"
    
    # Save query for reference
    echo "$query" > "$AUDIT_DIR/queries/$entry_id.txt"
}

# === LOG MEMORY ACCESS ===
audit_memory_access() {
    local agent="$1"
    local memory_id="$2"
    local memory_type="$3"
    local operation="$4"  # read, write, update, delete
    
    local entry_id
    entry_id=$(brainx_generate_id)
    local timestamp
    timestamp=$(date -Iseconds)
    
    local entry
    entry=$(jq -n --arg id "$entry_id" \
                     --arg agent "$agent" \
                     --arg memory_id "$memory_id" \
                     --arg memory_type "$memory_type" \
                     --arg operation "$operation" \
                     --arg timestamp "$timestamp" \
                     --arg type "memory_access" \
                     '{"id": $id, "type": $type, "agent": $agent, "memory_id": $memory_id, "memory_type": $memory_type, "operation": $operation, "timestamp": $timestamp}')
    
    echo "$entry" >> "$AUDIT_LOG"
    audit_index_entry "$entry_id" "memory_access" "$agent" "$timestamp"
}

# === LOG DECISION ===
audit_decision() {
    local agent="$1"
    local decision_id="$2"
    local context="$3"
    
    local entry_id
    entry_id=$(brainx_generate_id)
    local timestamp
    timestamp=$(date -Iseconds)
    
    local entry
    entry=$(jq -n --arg id "$entry_id" \
                     --arg agent "$agent" \
                     --arg decision_id "$decision_id" \
                     --arg context "$context" \
                     --arg timestamp "$timestamp" \
                     --arg type "decision" \
                     '{"id": $id, "type": $type, "agent": $agent, "decision_id": $decision_id, "context": $context, "timestamp": $timestamp}')
    
    echo "$entry" >> "$AUDIT_LOG"
    audit_index_entry "$entry_id" "decision" "$agent" "$timestamp"
}

# === LOG INTER-AGENT MESSAGE ===
audit_inter_agent() {
    local from_agent="$1"
    local to_agent="$2"
    local message_id="$3"
    local operation="$4"  # send, receive, broadcast
    
    local entry_id
    entry_id=$(brainx_generate_id)
    local timestamp
    timestamp=$(date -Iseconds)
    
    local entry
    entry=$(jq -n --arg id "$entry_id" \
                     --arg from "$from_agent" \
                     --arg to "$to_agent" \
                     --arg message_id "$message_id" \
                     --arg operation "$operation" \
                     --arg timestamp "$timestamp" \
                     --arg type "inter_agent" \
                     '{"id": $id, "type": $type, "from_agent": $from, "to_agent": $to, "message_id": $message_id, "operation": $operation, "timestamp": $timestamp}')
    
    echo "$entry" >> "$AUDIT_LOG"
    audit_index_entry "$entry_id" "inter_agent" "$from_agent" "$timestamp"
}

# === INDEX ENTRY ===
audit_index_entry() {
    local entry_id="$1"
    local entry_type="$2"
    local agent="$3"
    local timestamp="$4"
    
    local date_part
    date_part=$(echo "$timestamp" | cut -d'T' -f1)
    
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg entry_id "$entry_id" \
       --arg entry_type "$entry_type" \
       --arg agent "$agent" \
       --arg date "$date_part" \
       '.by_agent[$agent] += [$entry_id] |
        .by_date[$date] += [$entry_id] |
        .by_type[$entry_type] += [$entry_id]' \
       "$AUDIT_INDEX" > "$temp_file" && mv "$temp_file" "$AUDIT_INDEX"
}

# === QUERY AUDIT LOG ===
audit_query_logs() {
    local agent="${1:-*}"
    local type="${2:-*}"
    local date="${3:-*}"
    local limit="${4:-100}"
    
    local temp_file
    temp_file=$(mktemp)
    
    # Filter by criteria
    if [[ "$agent" != "*" ]] || [[ "$type" != "*" ]]; then
        jq -c --arg agent "$agent" \
             --arg type "$type" \
             --argjson limit "$limit" \
             '[.[] | 
              select(($agent == "*" or .agent == $agent) and 
                     ($type == "*" or .type == $type))] |
              sort_by(.timestamp) | 
              reverse | 
              take($limit)' \
             "$AUDIT_LOG" > "$temp_file"
    else
        tail -n "$limit" "$AUDIT_LOG" | jq -c '.' > "$temp_file" 2>/dev/null || echo "[]" > "$temp_file"
    fi
    
    cat "$temp_file"
}

# === GET AGENT ACTIVITY ===
audit_agent_activity() {
    local agent="$1"
    local days="${2:-7}"
    
    echo -e "${BOLD}Activity for: $agent${NC}"
    echo "========================"
    echo ""
    
    jq -r --arg agent "$agent" \
         --argjson days "$days" \
         '[.[] | 
          select(.agent == $agent) |
          select((.timestamp | strptime("%Y-%m-%dT%H:%M:%S") | mktime) > (now - $days * 86400))] |
          group_by(.type) | 
          .[] | 
          "\(.[0].type): \(length) events"' \
         "$AUDIT_LOG"
}

# === SECURITY REPORT ===
audit_security_report() {
    echo -e "${BOLD}Security Audit Report${NC}"
    echo "========================"
    echo ""
    
    echo -e "${RED}Memory Access Patterns:${NC}"
    jq -r 'select(.type == "memory_access") | 
            "\(.timestamp) - \(.agent) - \(.memory_type) \(.operation) - \(.memory_id)"' \
         "$AUDIT_LOG" | tail -20
    
    echo ""
    echo -e "${YELLOW}Inter-Agent Communications:${NC}"
    jq -r 'select(.type == "inter_agent") | 
            "\(.timestamp) - \(.from_agent) -> \(.to_agent) [\(.)]"' \
         "$AUDIT_LOG" | tail -20
    
    echo ""
    echo -e "${GREEN}Query Statistics:${NC}"
    jq -r 'select(.type == "query") | 
            "\(.timestamp) - \(.agent): \(.query) [\(.) results in \(.)ms]" | 
            split("\n")[-1]' \
         "$AUDIT_LOG" | tail -10
}

# === COMPLIANCE EXPORT ===
audit_export_compliance() {
    local output_file="${1:-compliance-audit.json}"
    local start_date="${2:-2024-01-01}"
    local end_date="${3:-$(date +%Y-%m-%d)}"
    
    jq --arg start "$start_date" \
       --arg end "$end_date" \
       '[.[] | 
        select(.timestamp >= $start and .timestamp <= $end)]' \
       "$AUDIT_LOG" > "$output_file"
    
    echo "Exported compliance audit to $output_file ($(wc -l < "$output_file") entries)"
}

# === AUDIT STATS ===
audit_stats() {
    echo -e "${BOLD}Audit Statistics${NC}"
    echo "=================="
    echo ""
    
    local total_entries
    total_entries=$(wc -l < "$AUDIT_LOG")
    echo "Total entries: $total_entries"
    echo ""
    
    echo -e "${CYAN}By Type:${NC}"
    jq -r 'group_by(.type) | .[] | "\(.[0].type): \(length)"' "$AUDIT_LOG" 2>/dev/null || echo "  No entries yet"
    
    echo ""
    echo -e "${CYAN}By Agent:${NC}"
    jq -r 'group_by(.agent) | .[] | "\(.[0].agent): \(length) events"' "$AUDIT_LOG" 2>/dev/null || echo "  No entries yet"
    
    echo ""
    echo -e "${CYAN}Recent Activity:${NC}"
    jq -r '.[-10:] | .[] | "\(.timestamp) [\(.type)] \(.agent // "system"): \(.query // .context // .decision_id // .message_id // .memory_id)"' \
         "$AUDIT_LOG" 2>/dev/null | head -10 || echo "  No recent activity"
}

# === CLEANUP OLD ENTRIES ===
audit_cleanup() {
    local days="${1:-90}"
    local temp_file
    temp_file=$(mktemp)
    
    jq --argjson days "$days" \
       '[.[] | 
        select((.timestamp | strptime("%Y-%m-%dT%H:%M:%S") | mktime) > (now - $days * 86400))]' \
       "$AUDIT_LOG" > "$temp_file" && mv "$temp_file" "$AUDIT_LOG"
    
    echo "Cleaned up entries older than $days days"
}
