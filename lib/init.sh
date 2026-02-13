#!/bin/bash
# BrainX V2 Initialization
# Loads all required modules for HTTP client and connection reuse

set -u

BRAINX_HOME="${BRAINX_HOME:-/home/clawd/.openclaw/workspace/skills/brainx-v2}"

# Load HTTP Client (Connection Reuse)
if [[ -f "$BRAINX_HOME/lib/http_client.sh" ]]; then
    source "$BRAINX_HOME/lib/http_client.sh"
fi

# Load Caching
if [[ -f "$BRAINX_HOME/lib/caching.sh" ]]; then
    source "$BRAINX_HOME/lib/caching.sh"
fi

# Load Batching
if [[ -f "$BRAINX_HOME/lib/batcher.sh" ]]; then
    source "$BRAINX_HOME/lib/batcher.sh"
fi

# Initialize HTTP client stats
if command -v http_stats &> /dev/null; then
    # Log on first load
    if [[ "${HTTP_CLIENT_INITIALIZED:-0}" == "0" ]]; then
        export HTTP_CLIENT_INITIALIZED=1
    fi
fi

# Export configuration for connection reuse
export HTTP_KEEP_ALIVE="${HTTP_KEEP_ALIVE:-300}"
export HTTP_MAX_RETRIES="${HTTP_MAX_RETRIES:-3}"
export HTTP_RETRY_DELAY="${HTTP_RETRY_DELAY:-1}"
export HTTP_MAX_PARALLEL="${HTTP_MAX_PARALLEL:-5}"
export CACHE_TTL="${CACHE_TTL:-3600}"
export CACHE_ENABLED="${CACHE_ENABLED:-true}"
export BATCH_ENABLED="${BATCH_ENABLED:-true}"
