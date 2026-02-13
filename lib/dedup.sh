#!/bin/bash
# Semantic Deduplication - Remove semantically similar content
# lib/dedup.sh
# Detects and removes duplicate or highly similar memories/context

set -euo pipefail

# === CONFIG ===
DEDUP_ENABLED="${DEDUP_ENABLED:-true}"
SIMILARITY_THRESHOLD="${SIMILARITY_THRESHOLD:-0.85}"
MIN_CONTENT_LENGTH="${MIN_CONTENT_LENGTH:-50}"
DEDUP_METHOD="${DEDUP_METHOD:-hybrid}"  # hash, ngram, semantic, hybrid

# === HASH-BASED DEDUP ===
# Fast exact and near-exact match detection
dedup_by_hash() {
    local items_json="$1"
    
    local seen_hashes=()
    local result="[]"
    
    local count
    count=$(echo "$items_json" | jq 'length')
    
    for i in $(seq 0 $((count - 1))); do
        local item
        item=$(echo "$items_json" | jq -r ".[$i]")
        
        local content
        content=$(echo "$item" | jq -r '.content // .')
        
        # Normalize for hashing
        local normalized
        normalized=$(echo "$content" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g' | head -c 200)
        
        local hash
        hash=$(echo "$normalized" | md5sum | cut -d' ' -f1)
        
        # Check if we've seen this hash
        local is_dup=false
        for seen in "${seen_hashes[@]}"; do
            if [[ "$seen" == "$hash" ]]; then
                is_dup=true
                break
            fi
        done
        
        if [[ "$is_dup" == "false" ]]; then
            seen_hashes+=("$hash")
            result=$(echo "$result" | jq --argjson item "$item" '. += [$item]')
        fi
    done
    
    echo "$result"
}

# === N-GRAM SIMILARITY ===
# Detect similar content using n-gram overlap
calculate_ngram_similarity() {
    local text1="$1"
    local text2="$2"
    local n="${3:-3}"
    
    # Normalize
    text1=$(echo "$text1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g')
    text2=$(echo "$text2" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g')
    
    # Generate n-grams
    local ngrams1 ngrams2
    ngrams1=$(echo "$text1" | tr ' ' '\n' | grep -v '^$' | awk -v n="$n" '
        {for(i=1;i<=NF;i++) words[i]=$i}
        END {for(i=1;i<=length(words)-n+1;i++) {for(j=0;j<n;j++) printf "%s ",words[i+j]; print ""}}
    ')
    
    ngrams2=$(echo "$text2" | tr ' ' '\n' | grep -v '^$' | awk -v n="$n" '
        {for(i=1;i<=NF;i++) words[i]=$i}
        END {for(i=1;i<=length(words)-n+1;i++) {for(j=0;j<n;j++) printf "%s ",words[i+j]; print ""}}
    ')
    
    # Count overlap
    local common
    common=$(echo -e "$ngrams1\n$ngrams2" | sort | uniq -d | wc -l)
    
    local total1 total2
    total1=$(echo "$ngrams1" | grep -v '^$' | wc -l)
    total2=$(echo "$ngrams2" | grep -v '^$' | wc -l)
    
    if [[ $total1 -eq 0 ]] || [[ $total2 -eq 0 ]]; then
        echo "0"
        return
    fi
    
    # Jaccard similarity
    local union=$((total1 + total2 - common))
    echo "scale=4; $common / $union" | bc 2>/dev/null || echo "0"
}

# === SEMANTIC KEYWORD OVERLAP ===
# Lightweight semantic similarity using keyword extraction
calculate_keyword_similarity() {
    local text1="$1"
    local text2="$2"
    
    # Extract keywords (content words)
    extract_keywords() {
        echo "$1" | tr '[:upper:]' '[:lower:]' | \
            grep -oE '\b[a-z]{4,}\b' | \
            grep -vE '\b(the|and|for|are|but|not|you|all|can|had|her|was|one|our|out|day|get|has|him|his|how|its|may|new|now|old|see|two|who|boy|did|she|use|her|way|many|oil|sit|set|run|eat|far|sea|eye|ago|off|too|any|say|man|try|ask|end|why|let|put|say|she|try|way|own|say|too|old|also|each|which|their|time|will|about|if|up|out|many|then|them|these|so|some|her|would|make|like|into|him|has|two|more|very|what|know|just|first|also|after|back|other|many|than|only|those|come|day|most|us|is|it|at|be|to|of|as|on|by|he|we|do|no|or|an|my|me|go|am|oh|ah)\b' | \
            sort | uniq -c | sort -rn | head -20 | awk '{print $2}'
    }
    
    local keywords1 keywords2
    keywords1=$(extract_keywords "$text1")
    keywords2=$(extract_keywords "$text2")
    
    # Count overlap
    local common
    common=$(echo -e "$keywords1\n$keywords2" | sort | uniq -d | wc -l)
    
    local total
    total=$(echo "$keywords1" | wc -l)
    
    if [[ $total -eq 0 ]]; then
        echo "0"
        return
    fi
    
    echo "scale=4; $common / $total" | bc 2>/dev/null || echo "0"
}

# === HYBRID SIMILARITY ===
combine_similarities() {
    local ngram_sim="$1"
    local keyword_sim="$2"
    
    # Weighted combination
    local combined
    combined=$(echo "scale=4; 0.6 * $ngram_sim + 0.4 * $keyword_sim" | bc 2>/dev/null || echo "0")
    
    # Return as float
    echo "$combined"
}

# === MAIN DEDUP FUNCTION ===
dedup_semantic() {
    local items_json="$1"
    local threshold="${2:-$SIMILARITY_THRESHOLD}"
    
    if [[ "$DEDUP_ENABLED" != "true" ]]; then
        echo "$items_json"
        return 0
    fi
    
    local count
    count=$(echo "$items_json" | jq 'length')
    
    if [[ $count -le 1 ]]; then
        echo "$items_json"
        return 0
    fi
    
    # Convert threshold to integer for comparison (0.85 -> 85)
    local threshold_int
    threshold_int=$(echo "$threshold * 100" | bc | cut -d. -f1)
    
    local kept_indices=()
    
    for i in $(seq 0 $((count - 1))); do
        local item_i
        item_i=$(echo "$items_json" | jq -r ".[$i]")
        
        local content_i
        content_i=$(echo "$item_i" | jq -r '.content // .')
        
        # Skip very short content
        if [[ ${#content_i} -lt $MIN_CONTENT_LENGTH ]]; then
            kept_indices+=("$i")
            continue
        fi
        
        local is_dup=false
        
        for j in "${kept_indices[@]}"; do
            local item_j
            item_j=$(echo "$items_json" | jq -r ".[$j]")
            
            local content_j
            content_j=$(echo "$item_j" | jq -r '.content // .')
            
            local similarity
            
            # First check: exact hash match (fast path)
            local hash_i hash_j
            hash_i=$(echo "$content_i" | tr '[:upper:]' '[:lower:]' | md5sum | cut -d' ' -f1)
            hash_j=$(echo "$content_j" | tr '[:upper:]' '[:lower:]' | md5sum | cut -d' ' -f1)
            if [[ "$hash_i" == "$hash_j" ]]; then
                similarity="1.0"
            else
                # Hash doesn't match, check based on method
                case "$DEDUP_METHOD" in
                    hash)
                        similarity="0.0"
                        ;;
                    ngram)
                        similarity=$(calculate_ngram_similarity "$content_i" "$content_j")
                        ;;
                    semantic)
                        similarity=$(calculate_keyword_similarity "$content_i" "$content_j")
                        ;;
                    hybrid|*)
                        local ngram_sim keyword_sim
                        ngram_sim=$(calculate_ngram_similarity "$content_i" "$content_j")
                        keyword_sim=$(calculate_keyword_similarity "$content_i" "$content_j")
                        similarity=$(combine_similarities "$ngram_sim" "$keyword_sim")
                        ;;
                esac
            fi
            
            local sim_int
            sim_int=$(echo "$similarity * 100" | bc | cut -d. -f1)
            
            if [[ $sim_int -ge $threshold_int ]]; then
                is_dup=true
                brainx_log DEBUG "Duplicate detected (similarity: $similarity)"
                break
            fi
        done
        
        if [[ "$is_dup" == "false" ]]; then
            kept_indices+=("$i")
        fi
    done
    
    # Build result array
    local result="[]"
    for idx in "${kept_indices[@]}"; do
        local item
        item=$(echo "$items_json" | jq -r ".[$idx]")
        result=$(echo "$result" | jq --argjson item "$item" '. += [$item]')
    done
    
    local removed=$((count - ${#kept_indices[@]}))
    if [[ $removed -gt 0 ]]; then
        brainx_log INFO "Semantic dedup: removed $removed duplicates (threshold: $threshold)" >&2
    fi
    
    echo "$result"
}

# === DEDUP CONTEXT ===
# Remove duplicate entries from context before injection
dedup_context() {
    local context="$1"
    
    # Split context into items and dedup
    local items
    items=$(echo "$context" | awk '/^## /{if(NR>1)print "---"; print} /^[^#]/{print}' | \
        awk 'BEGIN{RS="---"; ORS="---"} NF' | head -c -3)
    
    # Convert to JSON array for processing
    local items_json
    items_json=$(echo "$items" | jq -R -s 'split("---") | map(select(length > 0) | {content: .})')
    
    local deduped
    deduped=$(dedup_semantic "$items_json")
    
    # Convert back to text
    echo "$deduped" | jq -r '.[] | .content'
}

# === DEDUP MEMORIES ===
# Remove duplicate memories from storage search results
dedup_memories() {
    local memories_json="$1"
    dedup_semantic "$memories_json"
}

# === BRAINX DEDUP COMMAND ===
brainx_dedup() {
    local file="${1:-}"
    
    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        brainx_error "Usage: brainx-v2 dedup <items.json>"
        return 1
    fi
    
    echo -e "${BOLD}Semantic Deduplication${NC}"
    echo "======================="
    echo "Method: $DEDUP_METHOD"
    echo "Threshold: $SIMILARITY_THRESHOLD"
    echo ""
    
    local content
    content=$(cat "$file")
    
    local original_count
    original_count=$(echo "$content" | jq 'length')
    echo "Original items: $original_count"
    
    local deduped
    deduped=$(dedup_semantic "$content")
    
    local new_count
    new_count=$(echo "$deduped" | jq 'length')
    echo "After dedup: $new_count"
    echo "Removed: $((original_count - new_count))"
    echo ""
    
    echo "$deduped" | jq .
}

# === BATCH DEDUP FOR LARGE DATASETS ===
batch_dedup() {
    local items_json="$1"
    local batch_size="${2:-100}"
    
    local total_count
    total_count=$(echo "$items_json" | jq 'length')
    
    if [[ $total_count -le $batch_size ]]; then
        dedup_semantic "$items_json"
        return 0
    fi
    
    # Process in batches to avoid memory issues
    local batches=$(( (total_count + batch_size - 1) / batch_size ))
    local result="[]"
    
    for b in $(seq 0 $((batches - 1))); do
        local start=$((b * batch_size))
        local end=$((start + batch_size))
        
        local batch
        batch=$(echo "$items_json" | jq ".[$start:$end]")
        
        local deduped_batch
        deduped_batch=$(dedup_semantic "$batch")
        
        # Merge with accumulated result
        result=$(echo "$result" | jq --argjson new "$deduped_batch" '. + $new')
        
        # Dedup merged result periodically
        if [[ $((b % 5)) -eq 4 ]]; then
            result=$(dedup_semantic "$result")
        fi
    done
    
    # Final dedup
    dedup_semantic "$result"
}
