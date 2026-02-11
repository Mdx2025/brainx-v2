#!/bin/bash
# Storage Functions - Hot/Warm/Cold tiers
# lib/storage.sh

set -euo pipefail

# === ADD TO STORAGE ===
storage_add() {
    local type="$1"
    local content="$2"
    local context="${3:-}"
    local tier="${4:-warm}"
    
    local id
    id=$(brainx_generate_id)
    local timestamp
    timestamp=$(brainx_timestamp)
    
    local storage_dir
    case "$tier" in
        hot)
            storage_dir="$BRAINX_HOME/storage/hot"
            ;;
        warm)
            storage_dir="$BRAINX_HOME/storage/warm"
            ;;
        cold)
            storage_dir="$BRAINX_HOME/storage/cold"
            ;;
        *)
            storage_dir="$BRAINX_HOME/storage/warm"
            ;;
    esac
    
    # Create memory file
    cat > "$storage_dir/$id.json" <<EOF
{
  "id": "$id",
  "type": "$type",
  "content": $(echo "$content" | jq -Rs .),
  "context": $(echo "$context" | jq -Rs .),
  "tier": "$tier",
  "timestamp": "$timestamp",
  "access_count": 0
}
EOF
    
    # Index in RAG
    rag_index_content "$id" "$content" "$type"
    
    brainx_log DEBUG "Added memory $id to $tier storage"
    echo "$id"
}

# === GET FROM STORAGE ===
storage_get() {
    local id="$1"
    
    # Search all tiers
    for tier in hot warm cold; do
        local storage_dir="$BRAINX_HOME/storage/$tier"
        if [[ -f "$storage_dir/$id.json" ]]; then
            # Increment access count
            local access_count
            access_count=$(jq -r '.access_count' "$storage_dir/$id.json")
            jq ".access_count = $((access_count + 1))" "$storage_dir/$id.json" > "$storage_dir/$id.tmp" && \
                mv "$storage_dir/$id.tmp" "$storage_dir/$id.json"
            
            cat "$storage_dir/$id.json"
            return 0
        fi
    done
    
    brainx_error "Memory not found: $id"
    return 1
}

# === SEARCH ACROSS TIERS ===
storage_search() {
    local query="$1"
    local results=()
    
    # Search in all tiers
    # Convert query to lowercase for case-insensitive search
    local query_lower
    query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
    
    for tier in hot warm cold; do
        local storage_dir="$BRAINX_HOME/storage/$tier"
        if [[ -d "$storage_dir" ]]; then
            while IFS= read -r -d '' file; do
                # Get content and context from file
                local content context
                content=$(jq -r '.content' "$file" 2>/dev/null | tr '[:upper:]' '[:lower:]')
                context=$(jq -r '.context' "$file" 2>/dev/null | tr '[:upper:]' '[:lower:]')
                
                # Check if any word from query is in content or context
                local match=false
                for word in $query_lower; do
                    if [[ "$content" == *"$word"* ]] || [[ "$context" == *"$word"* ]]; then
                        match=true
                        break
                    fi
                done
                
                if [[ "$match" == "true" ]]; then
                    local id tier_name
                    id=$(jq -r '.id' "$file")
                    tier_name=$(jq -r '.tier' "$file")
                    
                    results+=("$id:$tier_name")
                fi
            done < <(find "$storage_dir" -name "*.json" -print0 2>/dev/null)
        fi
    done
    
    # Output results
    for result in "${results[@]}"; do
        echo "$result"
    done
}

# === PROMOTION ===
storage_promote() {
    local id="$1"
    local target_tier="${2:-hot}"
    
    for tier in warm cold; do
        local source_dir="$BRAINX_HOME/storage/$tier"
        if [[ -f "$source_dir/$id.json" ]]; then
            local content context type timestamp access_count
            content=$(jq -r '.content' "$source_dir/$id.json")
            context=$(jq -r '.context' "$source_dir/$id.json")
            type=$(jq -r '.type' "$source_dir/$id.json")
            timestamp=$(jq -r '.timestamp' "$source_dir/$id.json")
            access_count=$(jq -r '.access_count' "$source_dir/$id.json")
            
            # Remove from current tier
            rm "$source_dir/$id.json"
            
            # Add to new tier
            local target_dir="$BRAINX_HOME/storage/$target_tier"
            cat > "$target_dir/$id.json" <<EOF
{
  "id": "$id",
  "type": "$type",
  "content": $content,
  "context": $context,
  "tier": "$target_tier",
  "timestamp": "$timestamp",
  "access_count": $access_count
}
EOF
            
            brainx_log INFO "Promoted $id to $target_tier"
            return 0
        fi
    done
    
    brainx_error "Memory not found: $id"
    return 1
}

# === ARCHIVE ===
storage_archive() {
    local id="$1"
    
    for tier in hot warm; do
        local source_dir="$BRAINX_HOME/storage/$tier"
        if [[ -f "$source_dir/$id.json" ]]; then
            local content context type timestamp access_count
            content=$(jq -r '.content' "$source_dir/$id.json")
            context=$(jq -r '.context' "$source_dir/$id.json")
            type=$(jq -r '.type' "$source_dir/$id.json")
            timestamp=$(jq -r '.timestamp' "$source_dir/$id.json")
            access_count=$(jq -r '.access_count' "$source_dir/$id.json")
            
            # Remove from current tier
            rm "$source_dir/$id.json"
            
            # Add to cold storage
            cat > "$BRAINX_HOME/storage/cold/$id.json" <<EOF
{
  "id": "$id",
  "type": "$type",
  "content": $content,
  "context": $context,
  "tier": "cold",
  "timestamp": "$timestamp",
  "access_count": $access_count
}
EOF
            
            brainx_log INFO "Archived $id to cold storage"
            return 0
        fi
    done
    
    brainx_error "Memory not found: $id"
    return 1
}

# === PROGRESSIVE RECALL ===
storage_recall() {
    local context="${1:-}"
    local limit="${2:-10}"
    
    brainx_log INFO "Progressive recall with context: $context"
    
    # First check hot storage
    local hot_dir="$BRAINX_HOME/storage/hot"
    local recall_results=()
    
    if [[ -d "$hot_dir" ]]; then
        while IFS= read -r -d '' file; do
            local id type content timestamp
            id=$(jq -r '.id' "$file")
            type=$(jq -r '.type' "$file")
            content=$(jq -r '.content' "$file")
            timestamp=$(jq -r '.timestamp' "$file")
            
            # Score by access count and recency
            local score
            score=$(jq -r '.access_count' "$file")
            
            recall_results+=("$score:$id:$type:$content:$timestamp")
        done < <(find "$hot_dir" -name "*.json" -print0 2>/dev/null)
    fi
    
    # Sort by score and limit
    echo "${recall_results[@]}" | tr ' ' '\n' | sort -t: -k1 -rn | head -"$limit"
}

# === MEMORY MANAGEMENT FUNCTIONS ===
brainx_mem_add() {
    local type="${1:-}"
    local content="${2:-}"
    local context="${3:-}"
    local tier="${4:-warm}"
    
    if [[ -z "$type" ]] || [[ -z "$content" ]]; then
        brainx_error "Usage: brainx-v2 add <type> <content> [context] [tier]"
        return 1
    fi
    
    local id
    id=$(storage_add "$type" "$content" "$context" "$tier")
    echo -e "${GREEN}Added memory: $id${NC}"
    echo "$id"
}

brainx_mem_get() {
    local id="${1:-}"
    
    if [[ -z "$id" ]]; then
        brainx_error "Usage: brainx-v2 get <id>"
        return 1
    fi
    
    storage_get "$id" | jq .
}

brainx_mem_search() {
    local query="${1:-}"
    
    if [[ -z "$query" ]]; then
        brainx_error "Usage: brainx-v2 search <query>"
        return 1
    fi
    
    echo -e "${YELLOW}Search results for: $query${NC}"
    storage_search "$query"
}

brainx_recall() {
    local context="${1:-}"
    local limit="${2:-10}"
    
    echo -e "${CYAN}Progressive Recall${NC}"
    echo "==================="
    storage_recall "$context" "$limit" | while IFS=: read -r score id type content timestamp; do
        echo -e "${GREEN}[$score] $type${NC} - $timestamp"
        echo "  $content"
        echo ""
    done
}

brainx_tier_manage() {
    local tier="$1"
    shift
    local subcommand="${1:-list}"
    
    local tier_dir="$BRAINX_HOME/storage/$tier"
    
    case "$subcommand" in
        list|ls)
            echo -e "${BOLD}$tier storage${NC}"
            ls -la "$tier_dir" 2>/dev/null | tail -n +2 || echo "Empty"
            ;;
        count|cnt)
            echo "$(ls "$tier_dir" 2>/dev/null | wc -l)"
            ;;
        cleanup)
            # Remove entries older than 30 days with 0 access
            find "$tier_dir" -name "*.json" -mtime +30 -exec grep -l '"access_count": 0' {} \; -exec rm {} \;
            brainx_log INFO "Cleanup complete for $tier"
            ;;
        *)
            brainx_error "Unknown subcommand: $subcommand"
            ;;
    esac
}
