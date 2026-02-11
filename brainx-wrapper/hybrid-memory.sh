#!/bin/bash
# BrainX V2 Hybrid Memory Integration
# Híbrido: Aislamiento + Memoria Compartida
#
# Funciones:
# - ask_memory: Búsqueda proactiva antes de actuar
# - memory_briefing: Resumen al inicio
# - cross_agent_query: Consultar decisiones de otros agents
# - check_relevant_decisions: Verificar decisiones previas

# === CONFIG ===
BRAINX_HYBRID_ENABLED="${BRAINX_HYBRID_ENABLED:-true}"
BRAINX_AUTO_SEARCH="${BRAINX_AUTO_SEARCH:-true}"
BRAINX_BRIEFING_LIMIT="${BRAINX_BRIEFING_LIMIT:-5}"

# === 1. PREGUNTAR A LA MEMORIA ANTES DE ACTUAR ===
# ask_memory "qué necesito hacer"
# Returns: JSON con decisiones relevantes
ask_memory() {
    local query="$1"
    local limit="${2:-5}"

    if [ "$BRAINX_AUTO_SEARCH" != "true" ]; then
        echo "[]"
        return 0
    fi

    log "info" "ASK_MEMORY query='$query'"

    # Usar memory-nucleo recall
    if [ -x "$BRAINX_HOME/memory-nucleo" ]; then
        local result
        result=$("$BRAINX_HOME/memory-nucleo" recall "$query" "$limit" 2>/dev/null)
        echo "$result"
    else
        # Fallback a brainx search
        brainx search "$query" 2>/dev/null
    fi
}

# === 2. RESUMEN AL INICIO DE SESIÓN ===
# memory_briefing [topics...]
# Usage: memory_briefing "auth" "database" "api"
memory_briefing() {
    local topics="$*"
    local limit="${BRAINX_BRIEFING_LIMIT:-5}"

    if [ "$BRAINX_HYBRID_ENABLED" != "true" ]; then
        return 0
    fi

    log "info" "MEMORY_BRIEFING topics='$topics'"

    # Si no hay topics, usar contexto del agent
    if [ -z "$topics" ]; then
        topics="$BRAINX_AGENT_NAME"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧠 MEMORY BRIEFING @$BRAINX_AGENT_ID"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Buscar decisiones relevantes
    if [ -x "$BRAINX_HOME/memory-nucleo" ]; then
        "$BRAINX_HOME/memory-nucleo" recall "$topics" "$limit" 2>/dev/null | head -c 2000
    else
        brainx search "$topics" 2>/dev/null | head -c 2000
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# === 3. CROSS-AGENT QUERY ===
# query_other_agent "coder" "auth" 
# query_other_agent "writer" "documentation"
query_other_agent() {
    local target_agent="$1"
    local query="$2"
    local limit="${3:-3}"

    log "info" "CROSS_QUERY target=@$target_agent query='$query'"

    # Formato especial para consultas cross-agent
    local cross_query="@$target_agent $query"

    if [ -x "$BRAINX_HOME/memory-nucleo" ]; then
        "$BRAINX_HOME/memory-nucleo" recall "$cross_query" "$limit" 2>/dev/null
    else
        brainx search "$cross_query" 2>/dev/null
    fi
}

# === 4. CHECK DECISION CONFLICTS ===
# check_decision_conflicts "decision a tomar"
# Returns: JSON con conflictos potenciales
check_decision_conflicts() {
    local decision="$1"

    log "info" "CHECK_CONFLICTS decision='$decision'"

    # Buscar decisiones similares
    if [ -x "$BRAINX_HOME/memory-nucleo" ]; then
        local conflicts
        conflicts=$("$BRAINX_HOME/memory-nucleo" recall "$decision" 5 2>/dev/null)

        # Si hay decisiones previas, verificar si contradicen
        if echo "$conflicts" | grep -q "decision"; then
            echo "⚠️ DECISIÓN PREVIA ENCONTRADA:"
            echo "$conflicts"
            echo ""
            echo "🤔 ¿Deseas continuar o revisar primero?"
        else
            echo "✅ No se encontraron decisiones previas relacionadas."
        fi
    fi
}

# === 5. PROPAGAR DECISIÓN CRÍTICA ===
# propagate_decision "Qué se decidió" "Por qué" [agent1,agent2...]
propagate_decision() {
    local decision="$1"
    local reason="$2"
    local targets="${3:-all}"

    log "info" "PROPAGATE decision='$decision' targets=$targets"

    # Registrar como decisión HOT (alta prioridad)
    if [ "${BRAINX_CENTRAL_ENABLED:-false}" == "true" ]; then
        brainx hook decision "$BRAINX_AGENT_ID" "$decision" "$reason" 9 2>/dev/null
    fi

    # Broadcast si es para todos
    if [ "$targets" == "all" ]; then
        agent_broadcast "📢 DECISIÓN @$BRAINX_AGENT_ID:
$decision
 razón: $reason"
    else
        # Enviar a agents específicos
        IFS=',' read -ra AGENTS <<< "$targets"
        for agent in "${AGENTS[@]}"; do
            agent_send "$(echo -n "$agent" | tr -d ' ')" "📢 Decisión de @$BRAINX_AGENT_ID: $decision"
        done
    fi

    echo "✅ Decisión propagada"
}

# === 6. REGISTRAR Y CONSULTAR ===
# Decisión menor: solo registrar si alguien pregunta
record_and_check() {
    local topic="$1"
    local info="$2"

    log "info" "RECORD_AND_CHECK topic='$topic'"

    # Registrar en memoria (tier warm)
    if [ "${BRAINX_CENTRAL_ENABLED:-false}" == "true" ]; then
        brainx hook learning "$BRAINX_AGENT_ID" "$topic" "$info" 2>/dev/null
    fi

    # Preguntar si otros agents ya tienen info
    echo "💡 Consultando memoria sobre: $topic"
    ask_memory "$topic" 3
}

# === 7. AUTO-INIT EN SESIÓN ===
# Agregar al session_start automático
hybrid_session_start() {
    local context="${1:-}"

    log "info" "HYBRID_SESSION_START context=$context"

    # 1. Búsqueda proactiva del contexto
    if [ -n "$context" ]; then
        ask_memory "$context" 5 > /dev/null
    fi

    # 2. Resumen breve del agent
    if [ "$BRAINX_BRIEFING_ENABLED" == "true" ]; then
        memory_briefing "$context"
    fi
}

# === HELP ===
hybrid_help() {
    cat << EOF
🧠 HYBRID MEMORY - Comandos disponibles:

  ask_memory <query> [limit]     - Consultar memoria antes de actuar
  memory_briefing [topics...]    - Resumen de decisiones al inicio
  query_other_agent <agent> <q>  - Consultar decisiones de otro agent
  check_decision_conflicts <d>   - Verificar contradicciones
  propagate_decision <d> <r>     - Propagar decisión crítica
  record_and_check <topic> <info> - Registrar y consultar

  hybrid_session_start [ctx]     - Iniciar sesión con memoria

Ejemplo:
  source brainx-wrapper/agent-wrapper
  session_start "implementando auth"
  ask_memory "auth tokens" 3
  memory_briefing "auth security"

EOF
}

# Exportar funciones si es sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f ask_memory memory_briefing query_other_agent
    export -f check_decision_conflicts propagate_decision record_and_check
    export -f hybrid_session_start hybrid_help
fi
