#!/bin/bash
# Token Counting - Estimate and count tokens
# lib/counter.sh

set -euo pipefail

# === TOKEN ESTIMATION ===
count_tokens_estimate() {
    local text="$1"
    local char_count=${#text}
    echo $(( (char_count / 4) + 1 ))
}

# === COUNT TOKENS (with tiktoken) ===
count_tokens() {
    local text="$1"
    
    if command -v python3 &>/dev/null && python3 -c "import tiktoken" 2>/dev/null; then
        python3 << PYEOF
import tiktoken
text = """$text""".encode('utf-8')
enc = tiktoken.encoding_for_model("gpt-4")
tokens = enc.encode(text.decode('utf-8'))
print(len(tokens))
PYEOF
    else
        count_tokens_estimate "$text"
    fi
}

# === COUNT TOKENS IN FILE ===
count_tokens_file() {
    local file="$1"
    [[ ! -f "$file" ]] && echo "0" && return 1
    count_tokens "$(cat "$file")"
}

# === COUNT TOKENS IN JSON ===
count_tokens_json() {
    local json="$1"
    
    if command -v jq &>/dev/null; then
        python3 -c "
import json
import sys
import tiktoken

data = json.load(sys.stdin)
text = ' '.join(str(item) for item in data)

try:
    enc = tiktoken.encoding_for_model('gpt-4')
    tokens = enc.encode(text)
    print(len(tokens))
except:
    print(len(text) // 4)
" <<< "$json" 2>/dev/null || count_tokens_estimate "$json"
    else
        count_tokens_estimate "$json"
    fi
}

# === FORMAT TOKEN COUNT ===
format_tokens() {
    local tokens="$1"
    
    if [[ $tokens -lt 1000 ]]; then
        echo "${tokens}"
    elif [[ $tokens -lt 1000000 ]]; then
        echo "$(echo "scale=1; $tokens / 1000" | bc)K"
    else
        echo "$(echo "scale=2; $tokens / 1000000" | bc)M"
    fi
}

# === COST ESTIMATION (MiniMax M2.1) ===
COST_INPUT="${COST_INPUT:-0.15}"
COST_OUTPUT="${COST_OUTPUT:-0.60}"
COST_CACHE_READ="${COST_CACHE_READ:-0.02}"
COST_CACHE_WRITE="${COST_CACHE_WRITE:-0.10}"

estimate_cost() {
    local input_tokens="$1"
    local output_tokens="${2:-0}"
    local cache_read="${3:-0}"
    local cache_write="${4:-0}"
    
    local cost
    cost=$(echo "scale=6; ($input_tokens * $COST_INPUT + $output_tokens * $COST_OUTPUT + $cache_read * $COST_CACHE_READ + $cache_write * $COST_CACHE_WRITE) / 100" | bc)
    
    echo "$cost"
}

# === VERBOSE COUNT ===
count_tokens_verbose() {
    local text="$1"
    local tokens=$(count_tokens "$text")
    local chars=${#text}
    local words=$(echo "$text" | wc -w)
    
    cat <<EOF
Tokens: $tokens
Chars:  $chars
Words:  $words
Est. Cost: \$0.000$(estimate_cost $tokens)
EOF
}
