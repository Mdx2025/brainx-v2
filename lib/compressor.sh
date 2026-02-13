#!/bin/bash
# Prompt Compression - Reduce tokens while preserving meaning
# lib/compressor.sh

set -euo pipefail

# === CONFIG ===
COMPRESS_ENABLED="${COMPRESS_ENABLED:-true}"
COMPRESS_THRESHOLD="${COMPRESS_THRESHOLD:-500}"
COMPRESS_RATIO="${COMPRESS_RATIO:-0.4}"

# === REMOVE COMMENTS ===
strip_comments() {
    local text="$1"
    echo "$text" | sed 's/#.*$//g' | sed '/^[[:space:]]*$/d'
}

# === EXTRACT KEY POINTS ===
extract_key_points() {
    local text="$1"
    echo "$text" | grep -iE "(important|required|must|always|never|key|critical|essential)" | \
        sed 's/^[[:space:]]*//' | head -20
}

# === ABBREVIATE COMMON TERMS ===
abbreviate() {
    local text="$1"
    
    # Common abbreviations
    text="${text//information/info}"
    text="${text//configuration/config}"
    text="${text//application/app}"
    text="${text//server/srv}"
    text="${text//database/db}"
    text="${text//message/msg}"
    text="${text//response/resp}"
    text="${text//request/req}"
    text="${text//user/usr}"
    text="${text//admin/adm}"
    text="${text//directory/dir}"
    text="${text//file/fl}"
    text="${text//image/img}"
    text="${text//video/vid}"
    text="${text//audio/aud}"
    text="${text//document/doc}"
    text="${text//number/num}"
    text="${text//string/str}"
    text="${text//integer/int}"
    text="${text//boolean/bool}"
    text="${text//function/func}"
    text="${text//variable/var}"
    text="${text//constant/const}"
    text="${text//parameter/param}"
    text="${text//argument/arg}"
    text="${text//return/ret}"
    text="${text//error/err}"
    text="${text//warning/warn}"
    text="${text//debug/dbg}"
    text="${text//reference/ref}"
    text="${text//instance/inst}"
    text="${text//pattern/pat}"
    text="${text//context/ctx}"
    text="${text//environment/env}"
    text="${text//execute/exec}"
    text="${text//operation/op}"
    text="${text//option/opt}"
    
    echo "$text"
}

# === CONDENSE WHITESPACE ===
condense_whitespace() {
    local text="$1"
    echo "$text" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# === REMOVE REDUNDANT PHRASES ===
remove_redundant() {
    local text="$1"
    
    text="${text//it is important to note that/}"
    text="${text//in order to/to}"
    text="${text//due to the fact that/because}"
    text="${text//at this point in time/now}"
    text="${text//in the event that/if}"
    text="${text//for the purpose of/for}"
    text="${text//with the exception of/except}"
    text="${text//in the case of/if}"
    text="${text//as a matter of fact/}"
    text="${text//the fact that/that}"
    text="${text//is able to/can}"
    text="${text//has the ability to/can}"
    text="${text//make use of/use}"
    text="${text//give an example of/example:}"
    text="${text//this means that/so}"
    text="${text//in other words/}"
    text="${text//that is to say/}"
    
    echo "$text"
}

# === SHORTEN MARKUP ===
shorten_markup() {
    local text="$1"
    
    text="${text//\*\*\*/}"
    text="${text//##/}"
    text="${text//\#/}"
    text="${text//\`\`\`/}"
    text="${text//\`/}"
    
    echo "$text"
}

# === SEMANTIC COMPRESSION ===
compress_semantic() {
    local text="$1"
    local target_tokens="${2:-2000}"
    
    # Extract core semantic units (sentences with meaning)
    local sentences
    sentences=$(echo "$text" | grep -oE '[^.!?]+[.!?]+' | head -50)
    
    # Score sentences by keyword density
    local scored_sentences=()
    while IFS= read -r sentence; do
        local word_count
        word_count=$(echo "$sentence" | wc -w)
        local content_words
        content_words=$(echo "$sentence" | grep -oE '\w+' | wc -l)
        local score=$((content_words * 100 / (word_count + 1)))
        scored_sentences+=("$score|$sentence")
    done <<< "$sentences"
    
    # Sort by score and take top sentences up to target
    printf '%s\n' "${scored_sentences[@]}" | sort -t'|' -k1 -rn | cut -d'|' -f2- | head -30
}

# === MAIN COMPRESS FUNCTION ===
compress_prompt() {
    local text="$1"
    
    if [[ "$COMPRESS_ENABLED" != "true" ]]; then
        echo "$text"
        return 0
    fi
    
    # Check if compression is needed
    local token_count
    token_count=$(count_tokens_estimate "$text")
    
    if [[ $token_count -lt $COMPRESS_THRESHOLD ]]; then
        echo "$text"
        return 0
    fi
    
    # Apply compression steps (pass text as argument, not stdin)
    text=$(shorten_markup "$text")
    text=$(remove_redundant "$text")
    text=$(abbreviate "$text")
    text=$(condense_whitespace "$text")
    
    # Apply semantic compression if still too long
    token_count=$(count_tokens_estimate "$text")
    if [[ $token_count -gt $((COMPRESS_THRESHOLD * 2)) ]] && [[ "$SEMANTIC_COMPRESS" == "true" ]]; then
        text=$(compress_semantic "$text" "$((COMPRESS_THRESHOLD * COMPRESS_RATIO / 100))")
    fi
    
    echo "$text"
}

# === BUILD COMPACT PROMPT ===
build_compact_prompt() {
    local prompt_file="$1"
    
    if [[ ! -f "$prompt_file" ]]; then
        echo "ERROR: File not found: $prompt_file" >&2
        return 1
    fi
    
    local content
    content=$(cat "$prompt_file")
    
    local compact
    compact=$(compress_prompt "$content")
    
    # Add cache prefix if enabled
    if [[ "${CACHE_ENABLED:-true}" == "true" ]]; then
        compact="[CACHED_SYSTEM]
$compact"
    fi
    
    echo "$compact"
}

# === COMPRESS FILE IN PLACE ===
compress_file() {
    local file="$1"
    local backup="${file}.bak"
    
    cp "$file" "$backup"
    compress_prompt "$(cat "$file")" > "$file"
    echo "Compressed $file (backup: $backup)"
}

# === COMPATIBILITY ALIAS ===
compress_tokens() {
    compress_prompt "$@"
}

# === BRAINX COMPRESS COMMAND ===
brainx_compress() {
    local text="${*:-}"
    
    if [[ -z "$text" ]]; then
        brainx_error "Usage: brainx-v2 compress <text>"
        return 1
    fi
    
    local compressed
    compressed=$(compress_prompt "$text")
    
    local original_tokens estimated_tokens
    original_tokens=$(count_tokens_estimate "$text")
    estimated_tokens=$(count_tokens_estimate "$compressed")
    
    echo -e "${BOLD}Compression Result${NC}"
    echo "======================"
    echo -e "Original tokens: $original_tokens"
    echo -e "Compressed tokens: $estimated_tokens"
    echo -e "Reduction: $((100 - estimated_tokens * 100 / original_tokens))%"
    echo ""
    echo "$compressed"
}
