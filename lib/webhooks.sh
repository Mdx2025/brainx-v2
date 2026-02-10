#!/bin/bash
# Webhooks Module - External Notifications
# lib/webhooks.sh

set -euo pipefail

# === WEBHOOKS DIRECTORY ===
WEBHOOKS_DIR="$BRAINX_HOME/.webhooks"
WEBHOOKS_LOG="$WEBHOOKS_DIR/log.jsonl"

# === INITIALIZE ===
webhooks_init() {
    mkdir -p "$WEBHOOKS_DIR"
    mkdir -p "$WEBHOOKS_DIR/triggers"
    mkdir -p "$WEBHOOKS_DIR/history"
    [[ -f "$WEBHOOKS_LOG" ]] || touch "$WEBHOOKS_LOG"
}

# === REGISTER WEBHOOK ===
webhook_register() {
    local name="$1"
    local url="$2"
    local event="${3:-*}"  # session_start, session_end, decision, action, error, *
    local method="${4:-POST}"
    local headers="${5:-Content-Type: application/json}"
    local enabled="${6:-true}"
    
    local webhook_id
    webhook_id=$(brainx_generate_id)
    
    cat > "$WEBHOOKS_DIR/$webhook_id.json" <<EOF
{
  "id": "$webhook_id",
  "name": "$name",
  "url": "$url",
  "event": "$event",
  "method": "$method",
  "headers": "$headers",
  "enabled": $enabled,
  "created": "$(brainx_timestamp)",
  "trigger_count": 0,
  "last_trigger": null,
  "failed_count": 0
}
EOF
    
    brainx_log INFO "Webhook registered: $name ($event -> $url)"
    echo "$webhook_id"
}

# === TRIGGER WEBHOOK ===
webhook_trigger() {
    local webhook_id="$1"
    local payload="$2"
    local event_type="$3"
    
    [[ -f "$WEBHOOKS_DIR/$webhook_id.json" ]] || return 1
    
    local url method headers
    url=$(jq -r '.url' "$WEBHOOKS_DIR/$webhook_id.json")
    method=$(jq -r '.method' "$WEBHOOKS_DIR/$webhook_id.json")
    headers=$(jq -r '.headers' "$WEBHOOKS_DIR/$webhook_id.json")
    
    # Log the trigger
    local log_entry
    log_entry=$(jq -n --arg id "$webhook_id" \
                       --arg event "$event_type" \
                       --arg payload "$payload" \
                       --arg timestamp "$(brainx_timestamp)" \
                       '{"webhook_id": $id, "event": $event, "payload": $payload, "timestamp": $timestamp}')
    echo "$log_entry" >> "$WEBHOOKS_LOG"
    
    # Send the webhook
    local response
    local http_code
    
    if command -v curl &> /dev/null; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "$headers" \
            -d "$payload" \
            "$url" 2>/dev/null) || true
        http_code=$(echo "$response" | tail -1)
        response=$(echo "$response" | sed '$d')
    elif command -v wget &> /dev/null; then
        response=$(wget -q -O - --post-data="$payload" \
            --header="$headers" \
            "$url" 2>/dev/null) || true
        http_code=$?
    else
        brainx_log WARN "No curl or wget available for webhook"
        return 1
    fi
    
    # Update webhook stats
    local temp_file
    temp_file=$(mktemp)
    
    if [[ "$http_code" -ge 200 ]] && [[ "$http_code" -lt 300 ]]; then
        jq --arg webhook_id "$webhook_id" \
           --arg timestamp "$(brainx_timestamp)" \
           --argjson count 1 \
           '.last_trigger = $timestamp |
            .trigger_count += $count |
            .failed_count = 0' \
           "$WEBHOOKS_DIR/$webhook_id.json" > "$temp_file" && mv "$temp_file" "$WEBHOOKS_DIR/$webhook_id.json"
        
        brainx_log DEBUG "Webhook $webhook_id triggered successfully"
        return 0
    else
        jq --arg webhook_id "$webhook_id" \
           --arg timestamp "$(brainx_timestamp)" \
           --argjson count 1 \
           '.failed_count += $count |
            .last_error = "HTTP $http_code"' \
           "$WEBHOOKS_DIR/$webhook_id.json" > "$temp_file" && mv "$temp_file" "$WEBHOOKS_DIR/$webhook_id.json"
        
        brainx_log WARN "Webhook $webhook_id failed: HTTP $http_code"
        return 1
    fi
}

# === BROADCAST EVENT ===
webhook_broadcast() {
    local event_type="$1"
    local payload="$2"
    
    for webhook in "$WEBHOOKS_DIR"/*.json; do
        [[ -f "$webhook" ]] || continue
        
        local enabled event
        enabled=$(jq -r '.enabled' "$webhook")
        event=$(jq -r '.event' "$webhook")
        
        [[ "$enabled" == "true" ]] || continue
        [[ "$event" == "*" ]] || [[ "$event" == "$event_type" ]] || continue
        
        webhook_trigger "$(basename "$webhook" .json)" "$payload" "$event_type" &
    done
}

# === LIST WEBHOOKS ===
webhook_list() {
    echo -e "${BOLD}Registered Webhooks${NC}"
    echo "====================="
    
    for webhook in "$WEBHOOKS_DIR"/*.json; do
        [[ -f "$webhook" ]] || continue
        
        local name url event enabled trigger_count
        name=$(jq -r '.name' "$webhook")
        url=$(jq -r '.url' "$webhook")
        event=$(jq -r '.event' "$webhook")
        enabled=$(jq -r '.enabled' "$webhook")
        trigger_count=$(jq -r '.trigger_count' "$webhook")
        
        local status
        if [[ "$enabled" == "true" ]]; then
            status="🟢"
        else
            status="🔴"
        fi
        
        echo -e "$status $name"
        echo "   URL: $url"
        echo "   Event: $event | Triggers: $trigger_count"
        echo ""
    done
}

# === REMOVE WEBHOOK ===
webhook_remove() {
    local webhook_id="$1"
    rm -f "$WEBHOOKS_DIR/$webhook_id.json"
    brainx_log INFO "Webhook removed: $webhook_id"
}

# === TOGGLE WEBHOOK ===
webhook_toggle() {
    local webhook_id="$1"
    
    local current_state
    current_state=$(jq -r '.enabled' "$WEBHOOKS_DIR/$webhook_id.json")
    local new_state
    new_state=$([[ "$current_state" == "true" ]] && echo "false" || echo "true")
    
    local temp_file
    temp_file=$(mktemp)
    jq --argjson new_state "$new_state" \
       '.enabled = $new_state' \
       "$WEBHOOKS_DIR/$webhook_id.json" > "$temp_file" && mv "$temp_file" "$WEBHOOKS_DIR/$webhook_id.json"
    
    brainx_log INFO "Webhook $webhook_id enabled: $new_state"
}

# === TEST WEBHOOK ===
webhook_test() {
    local webhook_id="$1"
    
    local payload
    payload=$(jq -n --arg event "test" \
                    --arg timestamp "$(brainx_timestamp)" \
                    '{"event": $event, "timestamp": $timestamp, "test": true}')
    
    webhook_trigger "$webhook_id" "$payload" "test"
}

# === VIEW WEBHOOK LOGS ===
webhook_logs() {
    local count="${1:-50}"
    tail -n "$count" "$WEBHOOKS_LOG" | jq -r '.'
}

# === SEND TO DISCORD ===
webhook_send_discord() {
    local webhook_url="$1"
    local message="$2"
    local username="${3:-BrainX}"
    
    local payload
    payload=$(jq -n --arg username "$username" \
                       --arg content "$message" \
                       '{"username": $username, "content": $content}')
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook_url" > /dev/null
}

# === SEND TO SLACK ===
webhook_send_slack() {
    local webhook_url="$1"
    local message="$2"
    local channel="${3:-#general}"
    
    local payload
    payload=$(jq -n --arg channel "$channel" \
                       --arg text "$message" \
                       '{"channel": $channel, "text": $text}')
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook_url" > /dev/null
}
