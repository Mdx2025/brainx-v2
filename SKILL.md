# BrainX V2 Skill

## Descripción General

BrainX V2 es el sistema unificado de inteligencia de memoria e optimización de contexto para OpenClaw. Integra gestión de memoria, RAG, y optimización de tokens en un solo CLI.

## Características Principales

### 🧠 Memoria Unificada
- **Almacenamiento en tiers**: HOT (crítico), WARM (activo), COLD (archivado)
- **Búsqueda semántica**: RAG con scoring de relevancia
- **Hooks de agentes**: Auto-registro de decisiones, acciones, aprendizajes

### ⚡ Optimización de Contexto (NUEVO)
- **Compresión de prompts**: Reduce tokens 40-60%
- **Conteo de tokens**: Tiktoken + fallback
- **Truncación inteligente**: Mantiene bajo presupuesto
- **Relevance Scoring**: Filtra contexto irrelevante
- **Prompt Caching**: 90% descuento en cache hits

### 📊 Métricas y Seguimiento
- Tracking de sesiones
- Costos por modelo
- Export a CSV
- Webhooks y scheduling

## Instalación

```bash
cd /home/clawd/.openclaw/workspace/skills/brainx-v2
chmod +x brainx-v2

# Verificar
./brainx-v2 health
```

## Uso Rápido

```bash
# Memoria
brainx-v2 add decision "Usar cache" "Performance"
brainx-v2 search "API auth"

# Optimización
brainx-v2 compress "system prompt largo..."
brainx-v2 cost "mi mensaje"
brainx-v2 optimize "query" "system" "history"

# RAG
brainx-v2 rag "cómo configurar nginx"
brainx-v2 rag index /path/to/docs
```

## Arquitectura

```
brainx-v2/
├── brainx-v2              # CLI principal
├── lib/
│   ├── core.sh            # Inicialización
│   ├── storage.sh         # Almacenamiento tiers
│   ├── rag.sh            # Búsqueda semántica
│   ├── hooks.sh          # Agente hooks
│   ├── compressor.sh     # Compresión de prompts
│   ├── counter.sh        # Conteo tokens
│   ├── truncator.sh      # Truncación historial
│   ├── relevance.sh      # Scoring relevancia
│   ├── optimizer.sh      # Pipeline completo
│   └── ...
├── config/brainx.conf     # Configuración
└── deploy-*.sh           # Deployment scripts
```

## Comandos de Optimización

| Comando | Descripción |
|---------|-------------|
| `compress <text>` | Comprimir prompt |
| `count <text>` | Contar tokens |
| `cost <text> [model]` | Estimar costo |
| `relevance <q> <ctx>` | Score relevancia |
| `optimize <q> [sys] [hist]` | Pipeline completo |
| `diagnose <ctx>` | Diagnosticar tamaño |

## Pipeline de Optimización

```
Input: system_prompt + chat_history + memories
  ↓
1. BrainX Search (relevant memories)
  ↓
2. Relevance Scoring (filter LOW)
  ↓
3. Prompt Compression
  ↓
4. History Truncation (fit budget)
  ↓
5. Cache Setup ([CACHED_SYSTEM])
  ↓
Output: Optimized context → LLM
```

## Ahorro de Tokens

| Componente | Antes | Después | Reducción |
|------------|-------|---------|-----------|
| System Prompt | 12K | 5K | ~58% |
| Chat History | 50K | 20K | ~60% |
| Memories | 30K | 10K | ~67% |
| **Total** | **~35K** | **~13K** | **~63%** |

## Integración con Agentes

```bash
# En scripts de agentes
source /home/clawd/.openclaw/workspace/skills/brainx-v2/brainx-v2

# Optimizar antes de enviar
optimized=$(optimize_context "$query" "$system" "$history")
brainx cost "$optimized"
```

## Configuración

Ver `config/brainx.conf`:

```bash
# Compresión
COMPRESS_ENABLED=true
COMPRESS_THRESHOLD=5000

# Budget
TOKEN_BUDGET=150000
WARNING_THRESHOLD=100000

# Scoring
RELEVANCE_THRESHOLD=70
```

## Requisitos

- Bash 4.0+
- Python 3.8+ (para tiktoken, opcional)
- jq (recomendado)
- PostgreSQL (opcional, para persistencia)

## Documentación Adicional

- `ARCHITECTURE.md` - Arquitectura detallada
- `OPTIMIZATIONS.md` - Guía de optimizaciones
- `AGENTS.md` - Uso con múltiples agentes

## Licencia

MIT
