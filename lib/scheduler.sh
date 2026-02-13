#!/bin/bash
# Scheduler Module - Distributed Cron Jobs
# lib/scheduler.sh

set -euo pipefail

# === SCHEDULER DIRECTORY ===
SCHEDULER_DIR="$BRAINX_HOME/.scheduler"
SCHEDULER_LOCK="$SCHEDULER_DIR/.lock"

# === INITIALIZE ===
scheduler_init() {
    mkdir -p "$SCHEDULER_DIR"
    mkdir -p "$SCHEDULER_DIR/logs"
    mkdir -p "$SCHEDULER_DIR/run"
}

# === ADD SCHEDULED TASK ===
scheduler_add() {
    local name="$1"
    local schedule="$2"  # cron format: "*/5 * * * *" or "interval:300" (seconds)
    local agent="$3"
    local command="$4"
    local enabled="${5:-true}"
    local description="${6:-}"
    
    local task_id
    task_id=$(brainx_generate_id)
    
    cat > "$SCHEDULER_DIR/$task_id.json" <<EOF
{
  "id": "$task_id",
  "name": "$name",
  "schedule": "$schedule",
  "agent": "$agent",
  "command": "$command",
  "enabled": $enabled,
  "description": "$description",
  "created": "$(brainx_timestamp)",
  "last_run": null,
  "last_status": null,
  "run_count": 0
}
EOF
    
    brainx_log INFO "Scheduled task added: $name ($schedule)"
    echo "$task_id"
}

# === REMOVE TASK ===
scheduler_remove() {
    local task_id="$1"
    rm -f "$SCHEDULER_DIR/$task_id.json"
    brainx_log INFO "Scheduled task removed: $task_id"
}

# === LIST TASKS ===
scheduler_list() {
    echo -e "${BOLD}Scheduled Tasks${NC}"
    echo "==================="
    
    for task in "$SCHEDULER_DIR"/*.json; do
        [[ -f "$task" ]] || continue
        
        local name enabled schedule agent last_run
        name=$(jq -r '.name' "$task")
        enabled=$(jq -r '.enabled' "$task")
        schedule=$(jq -r '.schedule' "$task")
        agent=$(jq -r '.agent' "$task")
        last_run=$(jq -r '.last_run // "never"' "$task")
        
        local status
        if [[ "$enabled" == "true" ]]; then
            status="🟢"
        else
            status="🔴"
        fi
        
        echo -e "$status $name"
        echo "   Schedule: $schedule | Agent: $agent"
        echo "   Last run: $last_run"
        echo ""
    done
}

# === RUN TASK NOW ===
scheduler_run() {
    local task_id="$1"
    
    [[ -f "$SCHEDULER_DIR/$task_id.json" ]] || {
        brainx_log ERROR "Task not found: $task_id"
        return 1
    }
    
    local command agent
    command=$(jq -r '.command' "$SCHEDULER_DIR/$task_id.json")
    agent=$(jq -r '.agent' "$SCHEDULER_DIR/$task_id.json")
    
    brainx_log INFO "Running task $task_id: $command"
    
    # Create run directory
    local run_dir="$SCHEDULER_DIR/run/$task_id-$(date +%s)"
    mkdir -p "$run_dir"
    
    # Run with agent context
    local output_file="$run_dir/output.log"
    local start_time
    start_time=$(date +%s)
    
    # Execute command and capture output
    if bash -c "$command" > "$output_file" 2>&1; then
        local status="success"
    else
        local status="failed"
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update task record
    local temp_file
    temp_file=$(mktemp)
    jq --arg task_id "$task_id" \
       --arg status "$status" \
       --argjson duration "$duration" \
       --arg output "$(cat "$output_file")" \
       '.last_run = "'$(brainx_timestamp)'" |
        .last_status = $status |
        .run_count += 1 |
        .last_duration = $duration |
        .last_output = $output' \
       "$SCHEDULER_DIR/$task_id.json" > "$temp_file" && mv "$temp_file" "$SCHEDULER_DIR/$task_id.json"
    
    # Move logs
    mv "$output_file" "$SCHEDULER_DIR/logs/$task_id-$(date +%s).log"
    
    brainx_log INFO "Task $task_id completed: $status ($duration seconds)"
}

# === TOGGLE TASK ===
scheduler_toggle() {
    local task_id="$1"
    
    local current_state
    current_state=$(jq -r '.enabled' "$SCHEDULER_DIR/$task_id.json")
    local new_state
    new_state=$([[ "$current_state" == "true" ]] && echo "false" || echo "true")
    
    local temp_file
    temp_file=$(mktemp)
    jq --argjson new_state "$new_state" \
       '.enabled = $new_state' \
       "$SCHEDULER_DIR/$task_id.json" > "$temp_file" && mv "$temp_file" "$SCHEDULER_DIR/$task_id.json"
    
    brainx_log INFO "Task $task_id enabled: $new_state"
}

# === SCHEDULER DAEMON (for continuous operation) ===
scheduler_daemon() {
    scheduler_init
    
    brainx_log INFO "Starting scheduler daemon..."
    
    while true; do
        local now
        now=$(date +%s)
        
        for task in "$SCHEDULER_DIR"/*.json; do
            [[ -f "$task" ]] || continue
            
            local enabled schedule last_run
            enabled=$(jq -r '.enabled' "$task")
            [[ "$enabled" == "true" ]] || continue
            
            schedule=$(jq -r '.schedule' "$task")
            last_run=$(jq -r '.last_run // "0"' "$task")
            
            local last_run_epoch
            last_run_epoch=$(date -d "$last_run" +%s 2>/dev/null || echo 0)
            
            # Check if interval has passed
            if [[ "$schedule" == interval:* ]]; then
                local interval="${schedule#interval:}"
                local next_run=$((last_run_epoch + interval))
                
                if [[ $now -ge $next_run ]]; then
                    scheduler_run "$(basename "$task" .json)"
                fi
            else
                # Cron format - simplified check (check if minute changed)
                local current_minute
                current_minute=$(date +%M)
                local last_minute
                last_minute=$(date -d "$last_run" +%M 2>/dev/null || echo "")
                
                if [[ "$current_minute" != "$last_minute" ]]; then
                    scheduler_run "$(basename "$task" .json)"
                fi
            fi
        done
        
        sleep 10
    done
}

# === CRON SYNC (generate crontab entries) ===
scheduler_sync_cron() {
    echo "# BrainX V2 Scheduled Tasks - Generated $(date)"
    echo "# Do not edit manually"
    echo ""
    
    for task in "$SCHEDULER_DIR"/*.json; do
        [[ -f "$task" ]] || continue
        
        local enabled schedule agent command name
        enabled=$(jq -r '.enabled' "$task")
        [[ "$enabled" == "true" ]] || continue
        
        schedule=$(jq -r '.schedule' "$task")
        agent=$(jq -r '.agent' "$task")
        command=$(jq -r '.command' "$task")
        name=$(jq -r '.name' "$task")
        
        # Convert to cron format if needed
        if [[ "$schedule" == interval:* ]]; then
            local interval="${schedule#interval:}"
            local cron_min
            cron_min=$((interval / 60))
            if [[ $cron_min -lt 60 ]]; then
                schedule="*/$cron_min * * * *"
            else
                local cron_hour=$((cron_min / 60))
                schedule="0 */$cron_hour * * *"
            fi
        fi
        
        echo "# $name"
        echo "$schedule cd /home/clawd/.openclaw/workspace-$agent && source brainx-wrapper/agent-wrapper && $command"
    done
}

# === WEBHOOK FOR TASK COMPLETION ===
scheduler_webhook() {
    local task_id="$1"
    local url="$2"
    
    # Register webhook callback
    local webhook_file="$SCHEDULER_DIR/webhooks/$task_id.json"
    mkdir -p "$(dirname "$webhook_file")"
    echo "{\"url\": \"$url\", \"created\": \"$(brainx_timestamp)\"}" > "$webhook_file"
    
    brainx_log INFO "Webhook registered for task $task_id: $url"
}
