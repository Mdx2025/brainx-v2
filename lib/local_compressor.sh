#!/bin/bash
# Local Model Compression using llama3.2-32k
# lib/local_compressor.sh
# Uses local Ollama model for intelligent context compression

set -euo pipefail

# === CONFIG ===
LOCAL_MODEL="${LOCAL_MODEL:-llama3.2-32k:latest}"
LOCAL_COMPRESS_ENABLED="${LOCAL_COMPRESS_ENABLED:-true}"
LOCAL_MAX_TOKENS="${LOCAL_MAX_TOKENS:-2000}"
LOCAL_TEMPERATURE="${LOCAL_TEMPERATURE:-0.1}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"

# === CHECK OLLAMA AVAILABILITY ===
ollama_available() {
    if [[ "$LOCAL_COMPRESS_ENABLED" != "true" ]]; then
        return 1
    fi
    
    curl -s "$OLLAMA_HOST/api/tags" > /dev/null 2>&1
}

# === COMPRESS WITH LOCAL MODEL ===
compress_with_local_model() {
    local text="$1"
    local target_tokens="${2:-2000}"
    
    if ! ollama_available; then
        brainx_log DEBUG "Ollama not available, falling back to standard compression"
        return 1
    fi
    
    local prompt
    prompt=$(cat <<EOF
You are a compression expert. Compress the following text while preserving all key information, facts, and relationships. Reduce to approximately $target_tokens tokens.

RULES:
1. Keep all specific facts, numbers, names, dates
2. Preserve cause-effect relationships
3. Maintain technical accuracy
4. Remove redundant explanations
5. Use concise bullet points when appropriate

TEXT TO COMPRESS:
$text

COMPRESSED VERSION:
EOF
)
    
    local response
    response=$(curl -s "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$LOCAL_MODEL\",
            \"prompt\": $(echo "$prompt" | jq -Rs .),
            \"stream\": false,
            \"options\": {
                \"temperature\": $LOCAL_TEMPERATURE,
                \"num_predict\": $target_tokens
            }
        }" 2>/dev/null | jq -r '.response // empty')
    
    if [[ -n "$response" ]]; then
        echo "$response"
        return 0
    fi
    
    return 1
}

# === SUMMARIZE CONTEXT WITH LOCAL MODEL ===
summarize_context_local() {
    local context="$1"
    local max_summary_tokens="${2:-500}"
    
    if ! ollama_available; then
        return 1
    fi
    
    local prompt
    prompt=$(cat <<EOF
Summarize the following context in a way that preserves information needed to answer questions. Maximum $max_summary_tokens tokens.

CONTEXT:
$context

SUMMARY (preserve key facts and relationships):
EOF
)
    
    curl -s "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$LOCAL_MODEL\",
            \"prompt\": $(echo "$prompt" | jq -Rs .),
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.1,
                \"num_predict\": $max_summary_tokens
            }
        }" 2>/dev/null | jq -r '.response // empty'
}

# === INTELLIGENT CONTEXT PRUNING ===
prune_context_local() {
    local query="$1"
    local context="$2"
    local relevance_threshold="${3:-0.7}"
    
    if ! ollama_available; then
        return 1
    fi
    
    local prompt
    prompt=$(cat <<EOF
Given the user query and context below, identify which parts of the context are relevant to answering the query. Return ONLY the relevant sections.

QUERY: $query

CONTEXT:
$context

RELEVANT SECTIONS ONLY:
EOF
)
    
    curl -s "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$LOCAL_MODEL\",
            \"prompt\": $(echo "$prompt" | jq -Rs .),
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.0,
                \"num_predict\": 2000
            }
        }" 2>/dev/null | jq -r '.response // empty'
}

# === BATCH PROCESS LOCAL ===
# Process multiple compression tasks in batch
batch_compress_local() {
    local items_json="$1"
    
    if ! ollama_available; then
        return 1
    fi
    
    local results="[]"
    local count
    count=$(echo "$items_json" | jq 'length')
    
    for i in $(seq 0 $((count - 1))); do
        local item
        item=$(echo "$items_json" | jq -r ".[$i]")
        local text
        text=$(echo "$item" | jq -r '.text')
        local target
        target=$(echo "$item" | jq -r '.target_tokens // 2000')
        
        local compressed
        compressed=$(compress_with_local_model "$text" "$target" || echo "$text")
        
        results=$(echo "$results" | jq --arg compressed "$compressed" '. += [$compressed]')
    done
    
    echo "$results"
}

# === BRAINX LOCAL COMPRESS COMMAND ===
brainx_local_compress() {
    local text="${*:-}"
    
    if [[ -z "$text" ]]; then
        brainx_error "Usage: brainx-v2 local-compress <text>"
        return 1
    fi
    
    if ! ollama_available; then
        brainx_error "Ollama not available at $OLLAMA_HOST"
        return 1
    fi
    
    echo -e "${BOLD}Local Model Compression${NC}"
    echo "========================"
    echo "Model: $LOCAL_MODEL"
    echo ""
    
    local compressed
    local start_time end_time duration
    start_time=$(date +%s)
    
    compressed=$(compress_with_local_model "$text")
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    local original_tokens compressed_tokens
    original_tokens=$(count_tokens_estimate "$text")
    compressed_tokens=$(count_tokens_estimate "$compressed")
    
    echo "Duration: ${duration}s"
    echo "Original: $original_tokens tokens"
    echo "Compressed: $compressed_tokens tokens"
    echo "Reduction: $((100 - compressed_tokens * 100 / original_tokens))%"
    echo ""
    echo "$compressed"
}

# === HEALTH CHECK ===
brainx_local_health() {
    echo -e "${BOLD}Local Model Health Check${NC}"
    echo "========================="
    
    if ollama_available; then
        echo -e "${GREEN}✓ Ollama available${NC} at $OLLAMA_HOST"
        
        local models
        models=$(curl -s "$OLLAMA_HOST/api/tags" | jq -r '.models[].name' 2>/dev/null)
        
        echo "Available models:"
        echo "$models" | while read -r model; do
            if [[ "$model" == *"llama3.2"* ]]; then
                echo -e "  ${GREEN}✓ $model${NC}"
            else
                echo "  • $model"
            fi
        done
    else
        echo -e "${RED}✗ Ollama not available${NC} at $OLLAMA_HOST"
        echo "Install from: https://ollama.ai"
    fi
}
