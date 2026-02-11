#!/bin/bash
# BrainX V2 Multi-Agent Deployment Script
# Deploys optimized context injection to all agents

set -euo pipefail

BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"
WRAPPER_DIR="$(cd "$(dirname "$0")/brainx-wrapper" && pwd)"
AGENTS_DIR="/home/clawd/.openclaw/agents"

echo "BrainX V2 Multi-Agent Deployment"
echo "================================="

# === DEPLOY TO ALL AGENTS ===
deploy_to_agents() {
    echo ""
    echo "Deploying to agents..."
    
    for agent_dir in "$AGENTS_DIR"/*/; do
        local agent_name
        agent_name=$(basename "$agent_dir")
        
        # Create brainx-wrapper directory if not exists
        mkdir -p "$agent_dir/brainx-wrapper"
        
        # Copy agent-wrapper
        cp "$WRAPPER_DIR/agent-wrapper" "$agent_dir/brainx-wrapper/"
        
        # Copy auto-integrate for automatic optimization
        cp "$WRAPPER_DIR/auto-integrate.sh" "$agent_dir/brainx-wrapper/"
        
        # Copy hybrid memory module
        cp "$WRAPPER_DIR/hybrid-memory.sh" "$agent_dir/brainx-wrapper/"
        
        # Create optimized context script
        cat > "$agent_dir/brainx-wrapper/optimize-context.sh" << 'SCRIPT'
#!/bin/bash
# Optimized Context Injection for Agent
# Uses BrainX V2 for compression and relevance scoring

BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"

source "$BRAINX_HOME/brainx-v2"

# Optimize context before sending to LLM
optimize_context() {
    local query="$1"
    local system_prompt="$2"
    local history="$3"
    local memories="$4"
    
    "$BRAINX_HOME/brainx-v2" optimize "$query" "$system_prompt" "$history"
}

# Quick compress for system prompt
compress_system() {
    local prompt="$1"
    "$BRAINX_HOME/brainx-v2" compress "$prompt"
}

# Estimate cost
estimate_cost() {
    local text="$1"
    "$BRAINX_HOME/brainx-v2" cost "$text"
}
SCRIPT
        
        chmod +x "$agent_dir/brainx-wrapper/optimize-context.sh"
        
        echo "  ✓ $agent_name"
    done
}

# === UPDATE WRAPPER TO USE OPTIMIZER ===
update_wrapper() {
    echo ""
    echo "Updating agent-wrapper with optimization..."
    
    # The agent-wrapper already has inject_context, but we can enhance it
    # to use the BrainX V2 optimization pipeline
}

# === VERIFY INSTALLATION ===
verify() {
    echo ""
    echo "Verifying installation..."
    
    local ok=0
    local total=0
    
    for agent_dir in "$AGENTS_DIR"/*/; do
        total=$((total + 1))
        if [[ -f "$agent_dir/brainx-wrapper/agent-wrapper" ]]; then
            ok=$((ok + 1))
            echo "  ✓ $(basename "$agent_dir")"
        fi
    done
    
    echo ""
    echo "Installed: $ok/$total agents"
}

# === MAIN ===
case "${1:-deploy}" in
    deploy)
        deploy_to_agents
        verify
        ;;
    verify)
        verify
        ;;
    *)
        echo "Usage: $0 [deploy|verify]"
        exit 1
        ;;
esac
