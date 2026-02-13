#!/bin/bash
# BrainX Optimizer - Main optimization pipeline
# lib/optimizer.sh

set -euo pipefail

# === CONFIG ===
OPTIMIZER_ENABLED="${OPTIMIZER_ENABLED:-true}"
OPTIMIZE_SYSTEM="${OPTIMIZE_SYSTEM:-true}"
OPTIMIZE_HISTORY="${OPTIMIZE_HISTORY:-true}"
OPTIMIZE_MEMORIES="${OPTIMIZE_MEMORIES:-true}"
TOKEN_BUDGET="${TOKEN_BUDGET:-150000}"
WARNING_THRESHOLD="${WARNING_THRESHOLD:-100000}"

# === LOAD LIBRARIES ===
load_optimizer_libs() {
    source "$BRAINX_HOME/lib/compressor.sh" 2>/dev/null || true
    source "$BRAINX_HOME/lib/counter.sh" 2>/dev/null || true
    source "$BRAINX_HOME/lib/truncator.sh" 2>/dev/null || true
    source "$BRAINX_HOME/lib/relevance.sh" 2>/dev/null || true
}

# === OPTIMIZE SYSTEM PROMPT ===
optimize_system_prompt() {
    local prompt="$1"
    
    if [[ "$OPTIMIZE_SYSTEM" != "true" ]]; then
        echo "$prompt"
        return 0
    fi
    
    compress_prompt "$prompt"
}

# === OPTIMIZE CHAT HISTORY ===
optimize_history() {
    local history="$1"
    
    if [[ "$OPTIMIZE_HISTORY" != "true" ]]; then
        echo "$history"
        return 0
    fi
    
    smart_truncate "$history"
}

# === FILTER MEMORIES BY QUERY ===
optimize_memories() {
    local query="$1"
    local memories="$2"
    
    if [[ "$OPTIMIZE_MEMORIES" != "true" ]]; then
        echo "$memories"
        return 0
    fi
    
    filter_relevant "$query" $memories
}

# === CHECK TOKEN BUDGET ===
check_token_budget() {
    local context="$1"
    
    local tokens
    tokens=$(count_tokens "$context")
    
    if [[ $tokens -gt $TOKEN_BUDGET ]]; then
        echo -e "${RED}ERROR: Token budget exceeded ($tokens > $TOKEN_BUDGET)${NC}" >&2
        return 1
    fi
    
    if [[ $tokens -gt $WARNING_THRESHOLD ]]; then
        echo -e "${YELLOW}WARNING: Approaching token limit ($tokens / $TOKEN_BUDGET)${NC}" >&2
    fi
    
    echo "$tokens"
}

# === FULL OPTIMIZATION PIPELINE ===
optimize_context() {
    local query="$1"
    local system_prompt="$2"
    local history="$3"
    local memories="$4"
    
    local optimized_context=""
    local total_tokens=0
    
    # Optimize system prompt
    if [[ -n "$system_prompt" ]]; then
        local opt_sys
        opt_sys=$(optimize_system_prompt "$system_prompt")
        local sys_tokens
        sys_tokens=$(count_tokens "$opt_sys")
        
        echo -e "${CYAN}System prompt: $sys_tokens tokens${NC}"
        
        # Prepend cache marker if large enough
        if [[ $sys_tokens -gt 10000 ]]; then
            opt_sys="[CACHED_SYSTEM]
$opt_sys"
        fi
        
        optimized_context="$opt_sys"
        ((total_tokens += sys_tokens))
    fi
    
    # Optimize history
    if [[ -n "$history" ]]; then
        local opt_hist
        opt_hist=$(optimize_history "$history")
        local hist_tokens
        hist_tokens=$(count_tokens "$opt_hist")
        
        echo -e "${CYAN}History: $hist_tokens tokens${NC}"
        
        if [[ -n "$optimized_context" ]]; then
            optimized_context="$optimized_context

$opt_hist"
        else
            optimized_context="$opt_hist"
        fi
        ((total_tokens += hist_tokens))
    fi
    
    # Filter and add memories
    if [[ -n "$memories" ]]; then
        local opt_mem
        opt_mem=$(optimize_memories "$query" "$memories")
        local mem_tokens
        mem_tokens=$(count_tokens "$opt_mem")
        
        echo -e "${CYAN}Memories: $mem_tokens tokens${NC}"
        
        if [[ -n "$optimized_context" ]]; then
            optimized_context="$optimized_context

Relevant Context:
$opt_mem"
        else
            optimized_context="$opt_mem"
        fi
        ((total_tokens += mem_tokens))
    fi
    
    # Check budget
    echo ""
    echo -e "${BOLD}Optimization Summary${NC}"
    echo "========================"
    echo -e "Total tokens: $total_tokens"
    echo -e "Budget: $TOKEN_BUDGET"
    
    if [[ $total_tokens -gt $TOKEN_BUDGET ]]; then
        echo -e "${RED}WARNING: Budget exceeded!${NC}"
    else
        echo -e "${GREEN}Within budget ✓${NC}"
    fi
    
    echo "$optimized_context"
}

# === QUICK OPTIMIZE ===
quick_optimize() {
    local text="$1"
    compress_prompt "$text"
}

# === COST OPTIMIZE ===
cost_optimize() {
    local input="$1"
    local model="${2:-MiniMax-M2.1}"
    
    local tokens
    tokens=$(count_tokens "$input")
    
    local est_cost
    est_cost=$(echo "scale=4; $tokens * $COST_INPUT / 1000000" | bc)
    
    cat <<EOF
Model: $model
Input Tokens: $(format_tokens $tokens)
Est. Cost: \$$est_cost
EOF
}

# === DIAGNOSE CONTEXT ===
diagnose_context() {
    local context="$1"
    
    echo -e "${BOLD}Context Diagnosis${NC}"
    echo "==================="
    echo ""
    
    local tokens
    tokens=$(count_tokens "$context")
    
    echo "Total Tokens: $(format_tokens $tokens)"
    echo "Lines: $(echo "$context" | wc -l)"
    echo "Chars: ${#context}"
    echo ""
    
    # Breakdown by section
    echo -e "${BOLD}Section Breakdown:${NC}"
    
    if echo "$context" | grep -q "\[CACHED_SYSTEM\]"; then
        echo "  [CACHED_SYSTEM] - Present ✓"
    fi
    
    if echo "$context" | grep -q "## System"; then
        echo "  System Prompt - Present ✓"
    fi
    
    if echo "$context" | grep -q "## History"; then
        echo "  Chat History - Present ✓"
    fi
    
    if echo "$context" | grep -q "## Memories"; then
        echo "  Relevant Memories - Present ✓"
    fi
}
