#!/bin/bash
# Second-Brain Functions
# lib/second-brain.sh

set -euo pipefail

# === SECOND-BRAIN DIRECTORY ===
KNOWLEDGE_DIR="$BRAINX_HOME/knowledge"

# === ADD TO SECOND-BRAIN ===
sb_add() {
    local category="$1"
    local content="$2"
    
    local id
    id=$(brainx_generate_id)
    local timestamp
    timestamp=$(brainx_timestamp)
    
    local category_dir="$KNOWLEDGE_DIR/$category"
    mkdir -p "$category_dir"
    
    # Create markdown entry
    cat > "$category_dir/$id.md" <<EOF
---
id: $id
category: $category
created: $timestamp
---

$content
EOF
    
    # Index in RAG
    rag_index_content "sb-$id" "$content" "second-brain"
    
    brainx_log DEBUG "Added to second-brain: $category"
    echo "$id"
}

# === SEARCH SECOND-BRAIN ===
sb_search() {
    local query="$1"
    
    local results=()
    
    # Search all knowledge files
    while IFS= read -r -d '' file; do
        if grep -qi "$query" "$file" 2>/dev/null; then
            local category
            category=$(basename "$(dirname "$file")")
            local content
            content=$(sed -n '7,$p' "$file" | head -5)
            
            echo "## [$category] $(basename "$file" .md)"
            echo "$content"
            echo ""
        fi
    done < <(find "$KNOWLEDGE_DIR" -name "*.md" -print0 2>/dev/null)
}

# === LIST CATEGORIES ===
sb_list() {
    echo -e "${BOLD}Second-Brain Categories${NC}"
    echo "=========================="
    
    if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
        echo "No knowledge directory"
        return 0
    fi
    
    for category_dir in "$KNOWLEDGE_DIR"/*/; do
        if [[ -d "$category_dir" ]]; then
            local category
            category=$(basename "$category_dir")
            local count
            count=$(ls "$category_dir"/*.md 2>/dev/null | wc -l)
            
            echo -e "${GREEN}$category${NC}: $count entries"
        fi
    done
}

# === BRAINX SECOND-BRAIN COMMAND ===
brainx_sb_manage() {
    local subcommand="${1:-list}"
    shift
    
    case "$subcommand" in
        add)
            local category="${1:-}"
            local content="${2:-}"
            
            if [[ -z "$category" ]] || [[ -z "$content" ]]; then
                brainx_error "Usage: brainx-v2 sb add <category> <content>"
                return 1
            fi
            
            local id
            id=$(sb_add "$category" "$content")
            echo -e "${GREEN}Added to second-brain: $id${NC}"
            ;;
        search)
            local query="${*:-}"
            
            if [[ -z "$query" ]]; then
                brainx_error "Usage: brainx-v2 sb search <query>"
                return 1
            fi
            
            sb_search "$query"
            ;;
        list)
            sb_list
            ;;
        *)
            brainx_error "Unknown second-brain command: $subcommand"
            ;;
    esac
}
