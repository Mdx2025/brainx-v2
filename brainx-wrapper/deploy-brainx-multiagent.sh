#!/bin/bash
# BrainX V2 Multi-Agent Deployment Script
# Deploya el wrapper a todos los workspaces y conecta a BrainX Centralizado
#
# Uso: ./deploy-brainx-multiagent.sh [--force]
#
# Arquitectura:
#   - Wrapper en cada workspace
#   - BrainX Centralizado (una sola DB)
#   - Cada agent tiene su AGENT_ID único

set -e

# === CONFIGURACIÓN CENTRAL ===
BRAINX_WRAPPER_SRC="/home/clawd/.openclaw/workspace-clawma/brainx-wrapper"
BRAINX_HOME="/home/clawd/.openclaw/workspace/skills/brainx-v2"
BRAINX_DB="${BRAINX_DB:-postgresql://brainx:brainx@localhost:5432/brainx_v2}"

# Lista de workspaces a deployar
WORKSPACES=(
    "workspace-clawma"
    "workspace-coder"
    "workspace-main"
    "workspace-projects"
    "workspace-reasoning"
    "workspace-researcher"
    "workspace-support"
    "workspace-writer"
)

# Mapeo workspace -> AGENT_ID
declare -A AGENT_IDS=(
    ["workspace-clawma"]="clawma"
    ["workspace-coder"]="coder"
    ["workspace-main"]="main"
    ["workspace-projects"]="projects"
    ["workspace-reasoning"]="reasoning"
    ["workspace-researcher"]="researcher"
    ["workspace-support"]="support"
    ["workspace-writer"]="writer"
)

# === COLORES ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# === VERIFICACIONES ===
verify_prerequisites() {
    log_info "Verificando prerrequisitos..."

    if [ ! -d "$BRAINX_WRAPPER_SRC" ]; then
        log_error "Wrapper source no encontrado: $BRAINX_WRAPPER_SRC"
        exit 1
    fi

    if [ ! -d "$BRAINX_HOME" ]; then
        log_warn "BrainX_HOME no encontrado: $BRAINX_HOME"
        log_warn "El wrapper se deployará pero requerirá instalación manual de BrainX V2"
    fi

    log_info "Prerrequisitos verificados ✓"
}

# === DEPLOYMENT ===
deploy_to_workspace() {
    local ws_name="$1"
    local ws_path="/home/clawd/.openclaw/$ws_name"
    local agent_id="${AGENT_IDS[$ws_name]}"
    local ws_wrapper="$ws_path/brainx-wrapper"

    log_info "Deploying a @$agent_id ($ws_path)..."

    # Crear directorio si no existe
    mkdir -p "$ws_wrapper"
    mkdir -p "$ws_wrapper/logs"

    # Copiar wrapper (excluyendo config y logs)
    rsync -av --exclude='config.sh' --exclude='logs/' \
          --exclude='*.log' "$BRAINX_WRAPPER_SRC/" "$ws_wrapper/" 2>/dev/null || {
        cp -r "$BRAINX_WRAPPER_SRC/"* "$ws_wrapper/" 2>/dev/null
    }

    # Crear config.sh específico para este workspace
    cat > "$ws_wrapper/config.sh" << EOF
#!/bin/bash
# BrainX V2 Config - Workspace: @$agent_id
# Auto-generado por deploy-brainx-multiagent.sh

# === RUTAS ===
WRAPPER_DIR="$ws_wrapper"
BRAINX_HOME="$BRAINX_HOME"
BRAINX_DB="$BRAINX_DB"

# === IDENTIDAD DEL AGENT ===
BRAINX_AGENT_ID="$agent_id"
BRAINX_AGENT_NAME="@$agent_id"
BRAINX_WORKSPACE="$ws_name"

# === LOGGING ===
LOG_LEVEL="info"
LOG_FILE="$ws_wrapper/logs/wrapper.log"
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

EOF

    # Hacer el wrapper ejecutable
    chmod +x "$ws_wrapper/agent-wrapper" 2>/dev/null

    log_info "  ✓ @$agent_id deployado"
}

# === REGISTRY ===
update_registry() {
    local registry_file="/home/clawd/.openclaw/.brainx-agents-registry"

    log_info "Actualizando registro de agentes..."

    mkdir -p "$(dirname "$registry_file")"

    cat > "$registry_file" << EOF
# BrainX Multi-Agent Registry
# Generado: $(date -Iseconds)
# No editar manualmente

CLUSTER_NAME="openclaw-prod"
BRAINX_VERSION="v2"
DEPLOY_DATE="$(date -Iseconds)"

AGENTS=(
EOF

    for ws in "${WORKSPACES[@]}"; do
        local agent_id="${AGENT_IDS[$ws]}"
        local ws_wrapper="/home/clawd/.openclaw/$ws/brainx-wrapper"
        local status="unknown"
        
        if [ -f "$ws_wrapper/agent-wrapper" ] && [ -f "$ws_wrapper/config.sh" ]; then
            status="ready"
        fi

        cat >> "$registry_file" << EOF
    "$agent_id:$ws:$status"
EOF
    done

    cat >> "$registry_file" << EOF
)
EOF

    log_info "Registro actualizado: $registry_file"
}

# === HEALTH CHECK ===
health_check_all() {
    log_info "Health check de todos los agentes..."

    local failed=0

    for ws in "${WORKSPACES[@]}"; do
        local agent_id="${AGENT_IDS[$ws]}"
        local ws_wrapper="/home/clawd/.openclaw/$ws/brainx-wrapper"

        if [ -f "$ws_wrapper/agent-wrapper" ]; then
            echo -n "  @$agent_id: "
            if bash "$ws_wrapper/agent-wrapper" health_check 2>/dev/null; then
                echo "✓"
            else
                echo "⚠ (BrainX no responde)"
            fi
        else
            echo -e "  @$agent_id: ${RED}NO DEPLOYADO${NC}"
            ((failed++))
        fi
    done

    return $failed
}

# === MAIN ===
main() {
    local force=false
    if [ "$1" == "--force" ]; then
        force=true
    fi

    echo "========================================"
    echo "  BrainX V2 Multi-Agent Deployment"
    echo "========================================"
    echo ""
    echo "Workspaces: ${#WORKSPACES[@]}"
    echo "BrainX DB: $BRAINX_DB"
    echo ""

    verify_prerequisites

    echo ""
    log_info "Iniciando deployment..."
    echo ""

    for ws in "${WORKSPACES[@]}"; do
        deploy_to_workspace "$ws"
    done

    update_registry

    echo ""
    log_info "Deployment completado!"
    echo ""

    echo "========================================"
    echo "  Health Check"
    echo "========================================"
    health_check_all

    echo ""
    log_info "Para usar el wrapper en un workspace:"
    echo "  source /path/to/brainx-wrapper/agent-wrapper"
    echo ""
    log_info "Ejemplo:"
    echo "  source /home/clawd/.openclaw/workspace-coder/brainx-wrapper/agent-wrapper"
    echo "  session_start \"coder\" \"implementando feature X\""
}

main "$@"
