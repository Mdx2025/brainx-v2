#!/bin/bash
# Core BrainX Functions
# lib/core.sh

set -euo pipefail

# === LOGGING ===
brainx_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        ERROR)
            echo -e "${RED}[${timestamp}] ERROR: ${message}${NC}" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[${timestamp}] WARN: ${message}${NC}"
            ;;
        INFO)
            echo -e "${BLUE}[${timestamp}] INFO: ${message}${NC}"
            ;;
        DEBUG)
            if [[ "${VERBOSE:-false}" == "true" ]]; then
                echo -e "${CYAN}[${timestamp}] DEBUG: ${message}${NC}"
            fi
            ;;
        SUCCESS)
            echo -e "${GREEN}[${timestamp}] SUCCESS: ${message}${NC}"
            ;;
        *)
            echo -e "[${timestamp}] ${message}"
            ;;
    esac
}

# === ERROR HANDLING ===
brainx_error() {
    local message="$1"
    brainx_log ERROR "$message"
    return 1
}

brainx_error_exit() {
    local message="$1"
    brainx_log ERROR "$message"
    exit 1
}

brainx_handle_error() {
    local line_num="$1"
    local command="$2"
    brainx_log ERROR "Error occurred at line $line_num: $command"
}

# === INITIALIZATION ===
brainx_init() {
    brainx_log INFO "Initializing BrainX v${BRAINX_VERSION}..."
    
    # Create required directories
    mkdir -p "$BRAINX_HOME/storage/hot"
    mkdir -p "$BRAINX_HOME/storage/warm"
    mkdir -p "$BRAINX_HOME/storage/cold"
    mkdir -p "$BRAINX_HOME/rag-index"
    mkdir -p "$BRAINX_HOME/knowledge/CORE"
    mkdir -p "$BRAINX_HOME/hooks"
    mkdir -p "$BRAINX_HOME/tools"
    mkdir -p "$BRAINX_HOME/.cache"
    
    # Initialize RAG index
    rag_init
    
    brainx_log SUCCESS "BrainX initialized successfully"
}

# === LOAD LIBRARIES ===
brainx_load_libs() {
    local lib_dir="$BRAINX_HOME/lib"
    
    # Source all library files
    for lib in "$lib_dir"/*.sh; do
        if [[ -f "$lib" ]]; then
            brainx_log DEBUG "Loading library: $lib"
            source "$lib"
        fi
    done
}

# === HEALTH CHECK ===
brainx_health() {
    local status="healthy"
    local issues=()
    
    # Check directories
    [[ -d "$BRAINX_HOME/storage/hot" ]] || issues+=("hot storage missing")
    [[ -d "$BRAINX_HOME/storage/warm" ]] || issues+=("warm storage missing")
    [[ -d "$BRAINX_HOME/storage/cold" ]] || issues+=("cold storage missing")
    [[ -d "$BRAINX_HOME/rag-index" ]] || issues+=("RAG index missing")
    [[ -d "$BRAINX_HOME/knowledge/CORE" ]] || issues+=("knowledge CORE missing")
    
    # Check disk space
    local disk_usage
    disk_usage=$(df "$BRAINX_HOME" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ -n "$disk_usage" ]] && [[ "$disk_usage" -gt 90 ]]; then
        issues+=("disk usage high: ${disk_usage}%")
    fi
    
    # Generate report
    if [[ ${#issues[@]} -eq 0 ]]; then
        brainx_log SUCCESS "System health: OK"
        return 0
    else
        status="degraded"
        for issue in "${issues[@]}"; do
            brainx_log WARN "Health issue: $issue"
        done
        return 1
    fi
}

brainx_health_check() {
    echo -e "${BOLD}BrainX System Health Check${NC}"
    echo "================================"
    
    local total_memories=0
    total_memories=$(( $(ls "$BRAINX_HOME/storage/hot" 2>/dev/null | wc -l) + \
                       $(ls "$BRAINX_HOME/storage/warm" 2>/dev/null | wc -l) + \
                       $(ls "$BRAINX_HOME/storage/cold" 2>/dev/null | wc -l) ))
    
    echo -e "Storage Hot:   $(ls "$BRAINX_HOME/storage/hot" 2>/dev/null | wc -l) entries"
    echo -e "Storage Warm: $(ls "$BRAINX_HOME/storage/warm" 2>/dev/null | wc -l) entries"
    echo -e "Storage Cold: $(ls "$BRAINX_HOME/storage/cold" 2>/dev/null | wc -l) entries"
    echo -e "Total Memories: $total_memories"
    echo -e "RAG Index: $(ls "$BRAINX_HOME/rag-index" 2>/dev/null | wc -l) indexed files"
    echo ""
    
    brainx_health
}

# === STATISTICS ===
brainx_stats() {
    echo -e "${BOLD}BrainX Statistics${NC}"
    echo "===================="
    
    local hot_count warm_count cold_count sb_count
    hot_count=$(ls "$BRAINX_HOME/storage/hot" 2>/dev/null | wc -l)
    warm_count=$(ls "$BRAINX_HOME/storage/warm" 2>/dev/null | wc -l)
    cold_count=$(ls "$BRAINX_HOME/storage/cold" 2>/dev/null | wc -l)
    sb_count=$(find "$BRAINX_HOME/knowledge" -name "*.md" 2>/dev/null | wc -l)
    
    echo -e "${GREEN}Storage:${NC}"
    echo "  Hot:   $hot_count entries"
    echo "  Warm:  $warm_count entries"
    echo "  Cold:  $cold_count entries"
    echo "  Total: $((hot_count + warm_count + cold_count)) entries"
    echo ""
    echo -e "${CYAN}Second-Brain:${NC}"
    echo "  Knowledge entries: $sb_count"
    echo ""
    echo -e "${BLUE}RAG Index:${NC}"
    echo "  Indexed files: $(ls "$BRAINX_HOME/rag-index" 2>/dev/null | wc -l)"
    echo ""
    echo -e "${YELLOW}Cache:${NC}"
    echo "  Cached items: $(ls "$BRAINX_HOME/.cache" 2>/dev/null | wc -l)"
}

# === GENERATE UNIQUE ID ===
brainx_generate_id() {
    echo "$(date +%s)-$(head -c 8 /dev/urandom | xxd -p)"
}

# === GET CURRENT TIMESTAMP ===
brainx_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# === PARSE ARGUMENTS ===
brainx_parse_args() {
    local args=("$@")
    local parsed=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --json)
                OUTPUT_FORMAT=json
                shift
                ;;
            *)
                parsed+=("$1")
                shift
                ;;
        esac
    done
    
    echo "${parsed[@]}"
}
