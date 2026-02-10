#!/bin/bash
# BrainX V2 Config - Workspace: @clawma
# Auto-generado por deploy-brainx-multiagent.sh

# === RUTAS ===
WRAPPER_DIR="/home/clawd/.openclaw/workspace-clawma/brainx-wrapper"
BRAINX_HOME="/home/clawd/.openclaw/workspace/skills/brainx-v2"
BRAINX_DB="postgresql://brainx:brainx@localhost:5432/brainx_v2"

# === IDENTIDAD DEL AGENT ===
BRAINX_AGENT_ID="clawma"
BRAINX_AGENT_NAME="@clawma"
BRAINX_WORKSPACE="workspace-clawma"

# === LOGGING ===
LOG_LEVEL="info"
LOG_FILE="/home/clawd/.openclaw/workspace-clawma/brainx-wrapper/logs/wrapper.log"
MAX_LOG_SIZE=10485760
LOG_BACKUPS=5

# === AUTO-RECORDING ===
AUTO_RECORD_DECISIONS=true
AUTO_RECORD_ACTIONS=true
AUTO_RECORD_LEARNINGS=true
AUTO_INJECT_CONTEXT=true

# === SCORING ===
SCORE_THRESHOLD=70
CONTEXT_MAX_TOKENS=4000

# === BRAINX CENTRAL ===
BRAINX_CENTRAL_ENABLED=true
BRAINX_CLUSTER_NAME="openclaw-prod"

