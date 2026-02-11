#!/bin/bash
# BrainX V2 Migration Script
# Migra memorias del old system a BrainX V2 sin romper nada

set -e

BRAINX_HOME="/home/clawd/.openclaw/workspace/skills/brainx-v2"
OLD_MEMORIES="/home/clawd/.openclaw/workspace/.memory-system/storage/memories.jsonl"
MIGRATION_LOG="/tmp/brainx-migration-$(date +%s).log"

echo "🧠 BrainX V2 Migration Script"
echo "=============================="
echo ""

# Verificar que BrainX V2 existe
if [ ! -x "$BRAINX_HOME/brainx-v2" ]; then
    echo "❌ Error: BrainX V2 CLI no encontrado en $BRAINX_HOME"
    exit 1
fi

# Crear log vacío
touch "$MIGRATION_LOG"
echo "Log: $MIGRATION_LOG"

# Contadores
TOTAL=0
MIGRATED=0
SKIPPED=0
FAILED=0

echo ""
echo "🔍 Leyendo memorias del old system..."
echo ""

# Función para migrar cada memoria
migrate_memory() {
    local line="$1"
    local id=$(echo "$line" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    local type=$(echo "$line" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    local content=$(echo "$line" | grep -o '"content":"[^"]*"' | sed 's/"content":"//;s/"$//' | sed 's/\\n/\n/g' | sed 's/\\"/"/g')
    local context=$(echo "$line" | grep -o '"context":"[^"]*"' | sed 's/"context":"//;s/"$//' | sed 's/\\"/"/g')
    local tier=$(echo "$line" | grep -o '"tier":"[^"]*"' | cut -d'"' -f4)
    local agent=$(echo "$line" | grep -o '"agent":"[^"]*"' | cut -d'"' -f4)
    local tags=$(echo "$line" | grep -o '"tags":\[[^]]*\]' | sed 's/"tags":\[//;s/\]$//' | sed 's/"//g')
    
    TOTAL=$((TOTAL + 1))
    
    # Mapeo de tipos old → comandos BrainX V2
    case "$type" in
        "decision")
            # Extraer action y reason del content
            local action=$(echo "$content" | head -1)
            local reason=$(echo "$content" | tail -1)
            if $BRAINX_HOME/brainx-v2 hook decision "$agent" "$action" "$reason" 8 >> "$MIGRATION_LOG" 2>&1; then
                echo "  ✅ [$agent] decision: ${action:0:50}..."
                MIGRATED=$((MIGRATED + 1))
            else
                echo "  ❌ Failed: $id"
                FAILED=$((FAILED + 1))
            fi
            ;;
        "action")
            # Extraer description y result
            local desc=$(echo "$content" | head -1)
            local result=$(echo "$content" | tail -1)
            if $BRAINX_HOME/brainx-v2 hook action "$agent" "$desc" "$result" "" >> "$MIGRATION_LOG" 2>&1; then
                echo "  ✅ [$agent] action: ${desc:0:50}..."
                MIGRATED=$((MIGRATED + 1))
            else
                echo "  ❌ Failed: $id"
                FAILED=$((FAILED + 1))
            fi
            ;;
        "learning")
            if $BRAINX_HOME/brainx-v2 hook learning "$agent" "$content" "$context" >> "$MIGRATION_LOG" 2>&1; then
                echo "  ✅ [$agent] learning: ${content:0:50}..."
                MIGRATED=$((MIGRATED + 1))
            else
                echo "  ❌ Failed: $id"
                FAILED=$((FAILED + 1))
            fi
            ;;
        "gotcha")
            if $BRAINX_HOME/brainx-v2 hook gotcha "$agent" "$content" "$context" "medium" >> "$MIGRATION_LOG" 2>&1; then
                echo "  ✅ [$agent] gotcha: ${content:0:50}..."
                MIGRATED=$((MIGRATED + 1))
            else
                echo "  ❌ Failed: $id"
                FAILED=$((FAILED + 1))
            fi
            ;;
        "session_start")
            if $BRAINX_HOME/brainx-v2 hook start "$agent" "$content" >> "$MIGRATION_LOG" 2>&1; then
                echo "  ✅ [$agent] session_start: ${content:0:50}..."
                MIGRATED=$((MIGRATED + 1))
            else
                echo "  ❌ Failed: $id"
                FAILED=$((FAILED + 1))
            fi
            ;;
        "second_brain")
            # category es el context
            local category="$context"
            # Sanitizar category (quitar espacios, usar underscore)
            category=$(echo "$category" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
            if [ -z "$category" ] || [ "$category" = "null" ]; then
                category="migrated"
            fi
            if $BRAINX_HOME/brainx-v2 sb add "$category" "[MIGRATED from $agent] $content" >> "$MIGRATION_LOG" 2>&1; then
                echo "  ✅ [$agent] second_brain/$category: ${content:0:50}..."
                MIGRATED=$((MIGRATED + 1))
            else
                echo "  ❌ Failed: $id"
                FAILED=$((FAILED + 1))
            fi
            ;;
        "note")
            if $BRAINX_HOME/brainx-v2 add note "$content" "$context" "$tier" >> "$MIGRATION_LOG" 2>&1; then
                echo "  ✅ [$agent] note: ${content:0:50}..."
                MIGRATED=$((MIGRATED + 1))
            else
                echo "  ❌ Failed: $id"
                FAILED=$((FAILED + 1))
            fi
            ;;
        *)
            # Tipo desconocido - migrar como decision con warning
            echo "  ⚠️  [$agent] unknown type '$type', migrating as decision..."
            if $BRAINX_HOME/brainx-v2 hook decision "$agent" "[$type] $content" "$context" 5 >> "$MIGRATION_LOG" 2>&1; then
                echo "  ✅ [$agent] migrated as decision"
                MIGRATED=$((MIGRATED + 1))
            else
                echo "  ❌ Failed: $id"
                FAILED=$((FAILED + 1))
            fi
            ;;
    esac
}

export -f migrate_memory
export BRAINX_HOME
export MIGRATION_LOG

# Verificar que el archivo existe
if [ ! -f "$OLD_MEMORIES" ]; then
    echo "❌ Error: No se encontró el archivo de memorias: $OLD_MEMORIES"
    exit 1
fi

# Contar total
TOTAL_LINES=$(wc -l < "$OLD_MEMORIES")
echo "📊 Total de memorias a migrar: $TOTAL_LINES"
echo ""

# Hacer backup antes de migrar
BACKUP_FILE="/tmp/brainx-backup-$(date +%s).jsonl"
echo "💾 Hacendo backup..."
cp "$OLD_MEMORIES" "$BACKUP_FILE"
echo "   Backup: $BACKUP_FILE"
echo ""

echo "🚀 Iniciando migración..."
echo ""

# Migrar cada línea (skip empty lines)
while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$line" ] && [ "$line" != "{" ]; then
        # Procesar la línea
        migrate_memory "$line"
    fi
done < "$OLD_MEMORIES"

echo ""
echo "=============================="
echo "📈 RESUMEN DE MIGRACIÓN"
echo "=============================="
echo "Total procesadas:  $TOTAL"
echo "✅ Migradas:       $MIGRATED"
echo "❌ Fallidas:       $FAILED"
echo "📁 Log completo:   $MIGRATION_LOG"
echo "💾 Backup old:     $BACKUP_FILE"
echo ""

# Verificar que BrainX V2 funciona después de la migración
echo "🔍 Verificando que BrainX V2 funciona..."
if $BRAINX_HOME/brainx-v2 health >> "$MIGRATION_LOG" 2>&1; then
    echo "   ✅ BrainX V2 está saludable"
else
    echo "   ⚠️  BrainX V2 tuvo problemas de salud"
fi

echo ""
echo "🧠 MIGRACIÓN COMPLETADA"
echo ""
echo "Próximos pasos sugeridos:"
echo "1. Verificar algunas memorias: brainx-v2 search <query>"
echo "2. Ver stats: brainx-v2 stats"
echo "3. Probar RAG: brainx-v2 rag <query>"
echo ""
