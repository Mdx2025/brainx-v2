#!/bin/bash
# Agent Registry Functions
# lib/registry.sh

set -euo pipefail

# === REGISTRY FILE ===
REGISTRY_FILE="$BRAINX_HOME/tools/registry.json"

# === INITIALIZE REGISTRY ===
registry_init() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        cat > "$REGISTRY_FILE" <<EOF
{
  "version": "1.0",
  "agents": {},
  "last_updated": "$(date -Iseconds)"
}
EOF
    fi
}

# === REGISTER AGENT ===
registry_register() {
    local name="$1"
    local description="$2"
    local capabilities="$3"
    local version="${4:-1.0.0}"
    
    registry_init
    
    # Read current registry
    local registry_json
    registry_json=$(cat "$REGISTRY_FILE")
    
    # Add or update agent
    local agent_json
    agent_json=$(cat <<EOF
{
  "name": "$name",
  "description": "$description",
  "capabilities": $capabilities,
  "version": "$version",
  "registered_at": "$(date -Iseconds)",
  "last_active": null,
  "status": "active"
}
EOF
)
    
    # Update JSON
    echo "$registry_json" | jq --arg name "$name" --argjson agent "$agent_json" \
        '.agents[$name] = $agent | .last_updated = "'$(date -Iseconds)'"' > "$REGISTRY_FILE.tmp" && \
        mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
    
    brainx_log DEBUG "Registered agent: $name"
}

# === GET AGENT ===
registry_get() {
    local name="$1"
    
    registry_init
    
    if jq -e --arg name "$name" '.agents[$name]' "$REGISTRY_FILE" >/dev/null 2>&1; then
        jq --arg name "$name" '.agents[$name]' "$REGISTRY_FILE"
    else
        brainx_error "Agent not found: $name"
        return 1
    fi
}

# === LIST AGENTS ===
registry_list() {
    registry_init
    
    echo -e "${BOLD}Registered Agents${NC}"
    echo "==================="
    
    local agents
    agents=$(jq -r '.agents | keys[]' "$REGISTRY_FILE" 2>/dev/null || echo "")
    
    if [[ -z "$agents" ]]; then
        echo "No agents registered"
        return 0
    fi
    
    for agent in $agents; do
        local description status version
        description=$(jq -r --arg name "$agent" '.agents[$name].description // empty' "$REGISTRY_FILE")
        status=$(jq -r --arg name "$agent" '.agents[$name].status // empty' "$REGISTRY_FILE")
        version=$(jq -r --arg name "$agent" '.agents[$name].version // empty' "$REGISTRY_FILE")
        
        echo -e "${GREEN}$agent${NC} (v$version) - $status"
        echo "  $description"
        echo ""
    done
}

# === UPDATE ACTIVITY ===
registry_update_activity() {
    local name="$1"
    
    registry_init
    
    jq --arg name "$name" --arg time "$(date -Iseconds)" \
        '.agents[$name].last_active = $time' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && \
        mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
}

# === BRAINX AGENTS COMMAND ===
brainx_agents_list() {
    registry_list
}
