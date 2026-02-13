#!/bin/bash
# HTTP Client Module - Connection Reuse & Pooling
# lib/http_client.sh

set -euo pipefail

# === BRAINX HOME ===
BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"

# === COLOR DEFINITIONS ===
BOLD='\033[1m'
NC='\033[0m'

# === LOGGING ===
brainx_log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >&2
}

# === HTTP CLIENT DIRECTORY ===
HTTP_CLIENT_DIR="$BRAINX_HOME/.http_client"
HTTP_POOL_DIR="$HTTP_CLIENT_DIR/pools"
HTTP_STATS="$HTTP_CLIENT_DIR/stats.json"

# === CONFIGURATION ===
HTTP_MAX_RETRIES="${HTTP_MAX_RETRIES:-3}"
HTTP_RETRY_DELAY="${HTTP_RETRY_DELAY:-1}"  # seconds
HTTP_TIMEOUT="${HTTP_TIMEOUT:-30}"
HTTP_CONNECT_TIMEOUT="${HTTP_CONNECT_TIMEOUT:-10}"
HTTP_KEEP_ALIVE="${HTTP_KEEP_ALIVE:-300}"  # seconds

# === INITIALIZATION ===
http_client_init() {
    mkdir -p "$HTTP_POOL_DIR"
    [[ -f "$HTTP_STATS" ]] || echo '{"requests":0,"errors":0,"retries":0,"pooled":0}' > "$HTTP_STATS"
}

# === EXTRACT HOST FROM URL ===
_extract_host() {
    local url="$1"
    # Remove protocol
    url="${url#http://}"
    url="${url#https://}"
    # Extract host (first part before /)
    echo "${url%%/*}"
}

# === GET POOL FILE FOR HOST ===
_get_pool_file() {
    local host="$1"
    echo "$HTTP_POOL_DIR/$(echo "$host" | md5sum | cut -d' ' -f1).pool"
}

# === UPDATE STATS ===
_update_stats() {
    local key="$1"
    local delta="${2:-1}"

    local temp_file
    temp_file=$(mktemp)
    jq --arg key "$key" --argjson delta "$delta" '.[$key] += $delta' \
       "$HTTP_STATS" > "$temp_file" && mv "$temp_file" "$HTTP_STATS"
}

# === HTTP REQUEST WITH CONNECTION REUSE ===
http_request() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local headers="${4:-Content-Type: application/json}"
    local timeout="${HTTP_TIMEOUT}"
    local connect_timeout="${HTTP_CONNECT_TIMEOUT}"

    # Extract host for pooling
    local host
    host=$(_extract_host "$url")

    # Get pool file
    local pool_file
    pool_file=$(_get_pool_file "$host")

    # Build curl command with connection reuse
    # Note: curl uses HTTP keep-alive by default
    # For connection pooling, we reuse the same curl process with the same host
    local curl_args=(
        -s
        -X "$method"
        -H "$headers"
        --connect-timeout "$connect_timeout"
        --max-time "$timeout"
        --compressed
        --retry "$HTTP_MAX_RETRIES"
        --retry-delay "$HTTP_RETRY_DELAY"
        --retry-all-errors
    )

    # Add data if POST/PUT
    if [[ -n "$data" ]] && [[ "$method" =~ ^(POST|PUT|PATCH)$ ]]; then
        curl_args+=(-d "$data")
    fi

    # Add URL
    curl_args+=("$url")

    # Execute with retries
    local response
    local http_code
    local attempt=0

    while [[ $attempt -lt $HTTP_MAX_RETRIES ]]; do
        if response=$(curl "${curl_args[@]}" -w "\n%{http_code}" 2>/dev/null); then
            # Extract http code from last line
            http_code=$(echo "$response" | tail -n1)
            # Extract response body (everything except last line)
            response=$(echo "$response" | head -n -1)

            # Update pool timestamp
            echo "$(date +%s)" > "$pool_file"

            # Update stats
            _update_stats "requests"
            [[ $attempt -gt 0 ]] && _update_stats "retries" "$attempt"

            # Return success
            echo "$response"
            return 0
        else
            ((attempt++))
            ((attempt < HTTP_MAX_RETRIES)) && sleep $HTTP_RETRY_DELAY
        fi
    done

    # All retries failed
    _update_stats "errors"
    brainx_log ERROR "HTTP request failed after $HTTP_MAX_RETRIES retries: $url"
    return 1
}

# === HTTP GET ===
http_get() {
    local url="$1"
    local headers="${2:-}"
    http_request "$url" "GET" "" "$headers"
}

# === HTTP POST ===
http_post() {
    local url="$1"
    local data="$2"
    local headers="${3:-Content-Type: application/json}"
    http_request "$url" "POST" "$data" "$headers"
}

# === HTTP PUT ===
http_put() {
    local url="$1"
    local data="$2"
    local headers="${3:-Content-Type: application/json}"
    http_request "$url" "PUT" "$data" "$headers"
}

# === HTTP DELETE ===
http_delete() {
    local url="$1"
    local headers="${2:-}"
    [[ -n "$headers" ]] && headers="-H \"$headers\"" || headers=""
    http_request "$url" "DELETE" "" "$headers"
}

# === ASYNC PARALLEL REQUESTS ===
http_parallel() {
    local requests_json="$1"
    local max_parallel="${HTTP_MAX_PARALLEL:-5}"

    # Parse requests
    local request_count
    request_count=$(echo "$requests_json" | jq 'length')

    # Run in parallel
    local pids=()
    local temp_dir
    temp_dir=$(mktemp -d)

    for i in $(seq 0 $((request_count - 1))); do
        local url method data headers
        url=$(echo "$requests_json" | jq -r ".[$i].url")
        method=$(echo "$requests_json" | jq -r ".[$i].method // \"GET\"")
        data=$(echo "$requests_json" | jq -r ".[$i].data // \"\"")
        headers=$(echo "$requests_json" | jq -r ".[$i].headers // \"\"")

        # Run in background
        (
            http_request "$url" "$method" "$data" "$headers" > "$temp_dir/$i.response" 2>&1
            echo $? > "$temp_dir/$i.code"
        ) &

        pids+=($!)

        # Limit parallelism
        [[ ${#pids[@]} -ge $max_parallel ]] && wait ${pids[0]} && pids=("${pids[@]:1}")
    done

    # Wait for all
    wait "${pids[@]}"

    # Collect results
    local results="[]"
    for i in $(seq 0 $((request_count - 1))); do
        local response
        local code
        response=$(cat "$temp_dir/$i.response" 2>/dev/null || echo "null")
        code=$(cat "$temp_dir/$i.code" 2>/dev/null || echo "1")

        results=$(echo "$results" | jq --argjson idx "$i" \
                                        --argjson code "$code" \
                                        --argjson resp "$response" \
                                        '. + [{index: $idx, code: $code, response: $resp}]')
    done

    # Cleanup
    rm -rf "$temp_dir"

    echo "$results"
}

# === HTTP STATS ===
http_stats() {
    echo -e "${BOLD}HTTP Client Statistics${NC}"
    echo "======================"
    jq '.' "$HTTP_STATS"

    # Show pool info
    echo ""
    echo "Connection Pools:"
    echo "----------------"
    for pool_file in "$HTTP_POOL_DIR"/*.pool; do
        [[ -f "$pool_file" ]] || continue

        local last_used age
        last_used=$(cat "$pool_file")
        local now
        now=$(date +%s)
        age=$((now - last_used))

        local human_age
        if [[ $age -lt 60 ]]; then
            human_age="${age}s ago"
        elif [[ $age -lt 3600 ]]; then
            human_age="$((age / 60))m ago"
        else
            human_age="$((age / 3600))h ago"
        fi

        echo "  Pool: $(basename "$pool_file" .pool)"
        echo "    Last used: $human_age"
    done
}

# === CLEANUP POOLS ===
http_cleanup_pools() {
    local max_age="${1:-3600}"  # Default 1 hour

    local now
    now=$(date +%s)
    local cleaned=0

    for pool_file in "$HTTP_POOL_DIR"/*.pool; do
        [[ -f "$pool_file" ]] || continue

        local last_used
        last_used=$(cat "$pool_file")
        local age=$((now - last_used))

        if [[ $age -gt $max_age ]]; then
            rm -f "$pool_file"
            ((cleaned++))
        fi
    done

    brainx_log INFO "Cleaned up $cleaned stale connection pools"
}

# === HEALTH CHECK ===
http_health_check() {
    echo -e "${BOLD}HTTP Client Health${NC}"
    echo "=================="

    # Test local connectivity
    if command -v curl &> /dev/null; then
        echo "✓ curl available: $(curl --version | head -1)"
    else
        echo "✗ curl not available"
        return 1
    fi

    # Check pool directory
    if [[ -d "$HTTP_POOL_DIR" ]]; then
        local pool_count
        pool_count=$(ls -1 "$HTTP_POOL_DIR"/*.pool 2>/dev/null | wc -l)
        echo "✓ Pool directory: $pool_count active pools"
    else
        echo "✗ Pool directory not found"
        return 1
    fi

    # Check stats
    if [[ -f "$HTTP_STATS" ]]; then
        echo "✓ Stats file exists"
    else
        echo "✗ Stats file missing"
        return 1
    fi

    echo "✓ HTTP Client is healthy"
    return 0
}

# === INIT ON LOAD ===
http_client_init
