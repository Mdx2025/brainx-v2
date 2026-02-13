#!/bin/bash
# RAG Search Functions
# lib/rag.sh

set -euo pipefail

# === INITIALIZE RAG ===
rag_init() {
    local index_dir="$BRAINX_HOME/rag-index"
    
    mkdir -p "$index_dir"
    
    # Create metadata file
    if [[ ! -f "$index_dir/.metadata.json" ]]; then
        cat > "$index_dir/.metadata.json" <<EOF
{
  "version": "1.0",
  "created": "$(date -Iseconds)",
  "last_indexed": null,
  "document_count": 0
}
EOF
    fi
    
    brainx_log DEBUG "RAG index initialized at $index_dir"
}

# === INDEX CONTENT ===
rag_index() {
    local path="${1:-}"
    
    if [[ -z "$path" ]]; then
        brainx_error "Usage: brainx-v2 rag index <path>"
        return 1
    fi
    
    if [[ -f "$path" ]]; then
        rag_index_file "$path"
    elif [[ -d "$path" ]]; then
        rag_index_directory "$path"
    else
        brainx_error "Path not found: $path"
        return 1
    fi
}

rag_index_directory() {
    local dir="$1"
    local count=0
    
    while IFS= read -r -d '' file; do
        rag_index_file "$file"
        ((count++))
    done < <(find "$dir" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.sh" \) -print0 2>/dev/null)
    
    brainx_log INFO "Indexed $count files from $dir"
    echo "$count"
}

rag_index_file() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    local id
    id=$(echo "$filepath" | md5sum | cut -d' ' -f1)
    local content
    content=$(cat "$filepath" | tr '\n' ' ' | sed 's/"/\\"/g')
    
    # Create index entry
    cat > "$BRAINX_HOME/rag-index/$id.json" <<EOF
{
  "id": "$id",
  "filename": "$filename",
  "path": "$filepath",
  "content": "$content",
  "indexed": "$(date -Iseconds)",
  "lines": $(wc -l < "$filepath")
}
EOF
    
    # Update metadata
    local doc_count
    doc_count=$(jq '.document_count' "$BRAINX_HOME/rag-index/.metadata.json")
    jq ".document_count = $((doc_count + 1)) | .last_indexed = \"$(date -Iseconds)\"" \
        "$BRAINX_HOME/rag-index/.metadata.json" > "$BRAINX_HOME/rag-index/.metadata.tmp" && \
        mv "$BRAINX_HOME/rag-index/.metadata.tmp" "$BRAINX_HOME/rag-index/.metadata.json"
}

rag_index_content() {
    local id="$1"
    local content="$2"
    local type="$3"
    
    local indexed_content
    indexed_content=$(echo "$content" | tr '\n' ' ' | sed 's/"/\\"/g')
    
    cat > "$BRAINX_HOME/rag-index/$id.json" <<EOF
{
  "id": "$id",
  "type": "$type",
  "content": "$indexed_content",
  "indexed": "$(date -Iseconds)"
}
EOF
}

# === SEARCH ===
rag_search() {
    local query="$1"
    local limit="${2:-10}"
    
    if [[ -z "$query" ]]; then
        brainx_error "Usage: brainx-v2 rag <query>"
        return 1
    fi
    
    brainx_log DEBUG "RAG search: $query"
    
    local results=()
    
    # Simple keyword-based search (can be upgraded to vector search)
    while IFS= read -r -d '' file; do
        local id filename path content line_num
        
        id=$(jq -r '.id' "$file")
        filename=$(jq -r '.filename // empty' "$file")
        path=$(jq -r '.path // empty' "$file")
        content=$(jq -r '.content' "$file")
        
        # Calculate relevance score
        local score=0
        local query_words=($query)
        
        for word in "${query_words[@]}"; do
            local matches
            matches=$(echo "$content" | grep -oi "$word" | wc -l)
            score=$((score + matches * 10))
        done
        
        # Normalize score
        score=$((score > 100 ? 100 : score))
        
        if [[ $score -gt 0 ]]; then
            results+=("$score:$id:$filename:$path")
        fi
    done < <(find "$BRAINX_HOME/rag-index" -name "*.json" -print0 2>/dev/null)
    
    # Sort by score and output
    if [[ ${#results[@]} -gt 0 ]]; then
        echo "${results[@]}" | tr ' ' '\n' | sort -t: -k1 -rn | head -"$limit" | while IFS=: read -r score id filename path; do
            echo -e "${GREEN}[Score: $score]${NC} $filename"
            echo "  Path: $path"
            echo ""
        done
    else
        echo -e "${YELLOW}No RAG results found for: $query${NC}"
    fi
}

# === RAG MANAGEMENT ===
brainx_rag_manage() {
    local subcommand="${1:-search}"
    shift
    
    case "$subcommand" in
        search)
            rag_search "$@"
            ;;
        index)
            rag_index "$@"
            ;;
        stats)
            echo -e "${BOLD}RAG Statistics${NC}"
            echo "=================="
            cat "$BRAINX_HOME/rag-index/.metadata.json" | jq .
            echo ""
            echo "Indexed documents: $(ls "$BRAINX_HOME/rag-index"/*.json 2>/dev/null | wc -l)"
            ;;
        *)
            brainx_error "Unknown RAG command: $subcommand"
            ;;
    esac
}
