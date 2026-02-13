#!/bin/bash
# Agent Hook Functions
# lib/hooks.sh

set -euo pipefail

# === HOOKS DIRECTORY ===
HOOKS_DIR="$BRAINX_HOME/hooks"

# === START SESSION HOOK ===
hook_start() {
    local agent="$1"
    local context="$2"
    
    local id
    id=$(brainx_generate_id)
    local timestamp
    timestamp=$(brainx_timestamp)
    
    cat > "$HOOKS_DIR/session-$id.json" <<EOF
{
  "id": "$id",
  "type": "session_start",
  "agent": "$agent",
  "context": "$context",
  "timestamp": "$timestamp"
}
EOF
    
    brainx_log INFO "Session hook started: $agent"
    echo "$id"
}

# === RECORD DECISION ===
hook_decision() {
    local action="$1"
    local reason="$2"
    local importance="${3:-5}"
    
    local id
    id=$(brainx_generate_id)
    local timestamp
    timestamp=$(brainx_timestamp)
    
    cat > "$HOOKS_DIR/decision-$id.json" <<EOF
{
  "id": "$id",
  "type": "decision",
  "action": "$action",
  "reason": "$reason",
  "importance": $importance,
  "timestamp": "$timestamp"
}
EOF
    
    # Also add to hot storage
    storage_add "decision" "$action" "$reason" "hot"
    
    brainx_log DEBUG "Decision recorded: $action"
    echo "$id"
}

# === RECORD ACTION ===
hook_action() {
    local description="$1"
    local result="$2"
    local tags="${3:-}"
    
    local id
    id=$(brainx_generate_id)
    local timestamp
    timestamp=$(brainx_timestamp)
    
    cat > "$HOOKS_DIR/action-$id.json" <<EOF
{
  "id": "$id",
  "type": "action",
  "description": "$description",
  "result": "$result",
  "tags": "$tags",
  "timestamp": "$timestamp"
}
EOF
    
    # Also add to hot storage
    storage_add "action" "$description" "$result" "hot"
    
    brainx_log DEBUG "Action recorded: $description"
    echo "$id"
}

# === RECORD LEARNING ===
hook_learning() {
    local pattern="$1"
    local lesson="$2"
    local source="${3:-}"
    
    local id
    id=$(brainx_generate_id)
    local timestamp
    timestamp=$(brainx_timestamp)
    
    cat > "$HOOKS_DIR/learning-$id.json" <<EOF
{
  "id": "$id",
  "type": "learning",
  "pattern": "$pattern",
  "lesson": "$lesson",
  "source": "$source",
  "timestamp": "$timestamp"
}
EOF
    
    # Also add to hot storage
    storage_add "learning" "$pattern" "$lesson" "hot"
    
    brainx_log DEBUG "Learning recorded: $pattern"
    echo "$id"
}

# === RECORD GOTCHA ===
hook_gotcha() {
    local issue="$1"
    local workaround="$2"
    local severity="${3:-medium}"
    
    local id
    id=$(brainx_generate_id)
    local timestamp
    timestamp=$(brainx_timestamp)
    
    cat > "$HOOKS_DIR/gotcha-$id.json" <<EOF
{
  "id": "$id",
  "type": "gotcha",
  "issue": "$issue",
  "workaround": "$workaround",
  "severity": "$severity",
  "timestamp": "$timestamp"
}
EOF
    
    # Also add to hot storage
    storage_add "gotcha" "$issue" "$workaround" "hot"
    
    brainx_log DEBUG "Gotcha recorded: $issue"
    echo "$id"
}

# === END SESSION HOOK ===
hook_end() {
    local summary="$1"
    
    local id
    id=$(brainx_generate_id)
    local timestamp
    timestamp=$(brainx_timestamp)
    
    # Find active session
    local active_session
    active_session=$(find "$HOOKS_DIR" -name "session-*.json" -mmin -60 | tail -1)
    
    if [[ -n "$active_session" ]]; then
        local session_id
        session_id=$(basename "$active_session" | sed 's/session-\(.*\)\.json/\1/')
        
        cat > "$active_session.tmp" <<EOF
{
  "id": "$session_id",
  "type": "session_end",
  "summary": "$summary",
  "end_timestamp": "$timestamp"
}
EOF
        mv "$active_session.tmp" "$active_session"
    fi
    
    cat > "$HOOKS_DIR/end-$id.json" <<EOF
{
  "id": "$id",
  "type": "session_end",
  "summary": "$summary",
  "timestamp": "$timestamp"
}
EOF
    
    brainx_log INFO "Session hook ended: $summary"
    echo "$id"
}

# === HOOK MANAGEMENT ===
brainx_hook_manage() {
    local hook_type="${1:-}"
    shift
    
    case "$hook_type" in
        start)
            hook_start "$@"
            ;;
        decision)
            hook_decision "$@"
            ;;
        action)
            hook_action "$@"
            ;;
        learning)
            hook_learning "$@"
            ;;
        gotcha)
            hook_gotcha "$@"
            ;;
        end)
            hook_end "$@"
            ;;
        list|ls)
            echo -e "${BOLD}Recent Hooks${NC}"
            ls -lt "$HOOKS_DIR"/*.json 2>/dev/null | head -20 | while read -r line; do
                echo "$line"
            done
            ;;
        *)
            brainx_error "Unknown hook type: $hook_type"
            echo "Usage: brainx-v2 hook <start|decision|action|learning|gotcha|end> [args]"
            ;;
    esac
}
