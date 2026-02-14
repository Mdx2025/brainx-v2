# BrainX V2 - Capacidades Completas

> **Versión:** 2.1.0
> **Repo:** https://github.com/Mdx2025/brainx-v2
> **Última actualización:** 2026-02-14

---

## 📋 Resumen Ejecutivo

BrainX V2 es un sistema de memoria unificada para entornos multi-agente distribuidos. Proporciona almacenamiento en tiers, búsqueda RAG, hooks de sesión, métricas, scheduler, webhooks y auditoría.

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                      BrainX V2 Core                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ Storage  │ │   RAG     │ │  Hooks   │ │ Metrics  │       │
│  │ Tiers    │ │  Search   │ │ Tracking │ │ Tracking │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │Scheduler │ │ Webhooks  │ │  Audit   │ │  Second  │       │
│  │  Cron    │ │ Notifs    │ │  Logs    │ │  Brain   │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │  HTTP    │ │ Context   │ │Compressor│ │ Caching  │       │
│  │ Client   │ │Optimizer  │ │Semantic  │ │ Response │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
└─────────────────────────────────────────────────────────────┘
```

---

## 📚 Librerías (28 módulos)

### Core

| Librería | Propósito |
|----------|-----------|
| `core.sh` | Funciones base: init, log, error, health |
| `init.sh` | Auto-load initialization para agentes |
| `storage.sh` | CRUD de memorias en JSONL |
| `registry.sh` | Registro de agentes |
| `hooks.sh` | Sistema de hooks de sesión |

### Búsqueda y RAG

| Librería | Propósito |
|----------|-----------|
| `rag.sh` | Búsqueda semántica con embeddings |
| `relevance.sh` | Scoring de relevancia por keywords |
| `scoring.sh` | Algoritmos de puntuación |
| `filter.sh` | Filtrado por relevancia |

### Optimización de Tokens

| Librería | Propósito |
|----------|-----------|
| `compressor.sh` | Compresión semántica de contexto |
| `local_compressor.sh` | Compresión con Ollama local |
| `summarizer.sh` | Resumen progresivo de historial |
| `truncator.sh` | Truncado inteligente |
| `caching.sh` | Cache de respuestas por query |
| `dedup.sh` | Deduplicación semántica |
| `context_optimizer.sh` | Optimización completa de contexto |
| `estimator.sh` | Estimación de tokens y costos |
| `counter.sh` | Conteo de tokens/entradas |
| `optimizer.sh` | Optimización global del sistema |

### HTTP y Red

| Librería | Propósito |
|----------|-----------|
| `http_client.sh` | Connection pooling, retries, stats |

### Sistema

| Librería | Propósito |
|----------|-----------|
| `metrics.sh` | Tracking de tokens, costo, tiempo |
| `scheduler.sh` | Cron jobs agent-aware |
| `webhooks.sh` | Notificaciones externas (Discord, Slack) |
| `audit.sh` | Logs de auditoría completos |
| `batcher.sh` | Procesamiento en batch |

### Integración

| Librería | Propósito |
|----------|-----------|
| `inject.sh` | Pipeline de inyección de contexto |
| `context.sh` | Construcción de contexto para LLM |
| `second-brain.sh` | Knowledge base personal |

---

## 🔧 Comandos CLI

### Gestión de Memoria

```bash
brainx-v2 add <type> <content> [context] [tier]   # Agregar memoria
brainx-v2 get <id>                                 # Obtener por ID
brainx-v2 search <query>                           # Buscar en todas
brainx-v2 recall [context] [limit]                 # Recall progresivo
```

### Tiers de Storage

```bash
brainx-v2 hot|warm|cold <subcommand>               # List, count, cleanup
```

**Criterios de tiers:**

| Tier | Criterio | Lifetime | Uso |
|------|----------|----------|-----|
| 🔥 Hot | Decisiones críticas, errores activos | Permanente | Contexto inmediato |
| 🌡️ Warm | Actividad normal, learnings recientes | 30 días → cold | Contexto general |
| ❄️ Cold | Entradas antiguas, histórico | Permanente | Referencia histórica |

### Agent Hooks

```bash
brainx-v2 hook start <agent> <context>             # Iniciar sesión
brainx-v2 hook decision <action> <reason> [imp]    # Registrar decisión
brainx-v2 hook action <desc> <result> [tags]       # Registrar acción
brainx-v2 hook learning <pattern> <lesson> [src]   # Registrar aprendizaje
brainx-v2 hook gotcha <issue> <workaround> [sev]   # Registrar gotcha
brainx-v2 hook end <summary>                        # Terminar sesión
```

### RAG Search

```bash
brainx-v2 rag <query>                              # Búsqueda semántica
brainx-v2 rag index <path>                         # Indexar contenido
```

### Second Brain

```bash
brainx-v2 sb add <category> <content>              # Agregar conocimiento
brainx-v2 sb search <query>                        # Buscar
brainx-v2 sb list                                  # Listar categorías
```

### Optimización

```bash
brainx-v2 inject <query>                           # Pipeline completo
brainx-v2 filter <query>                           # Filtrar por relevancia
brainx-v2 compress <text>                          # Comprimir texto
brainx-v2 local-compress <text>                    # Comprimir con Ollama
brainx-v2 local-health                             # Estado Ollama
brainx-v2 dedup <items.json>                       # Deduplicar
brainx-v2 summarize <messages.json>                # Resumir historial
brainx-v2 count <text>                             # Contar tokens
brainx-v2 truncate <json>                          # Truncar historial
brainx-v2 relevance <query> <context>              # Score de relevancia
brainx-v2 optimize <query> [system] [history]      # Pipeline optimización
brainx-v2 diagnose <context>                       # Diagnosticar tamaño
brainx-v2 cost <text> [model]                      # Estimar costo
brainx-v2 budget                                   # Estado del budget
```

### Métricas

```bash
brainx-v2 metrics start <agent> <context>          # Iniciar sesión
brainx-v2 metrics tokens <session> <in> <out> <cost>  # Track tokens
brainx-v2 metrics end <session> <summary>          # Terminar sesión
brainx-v2 metrics report                           # Ver reporte
brainx-v2 metrics export [csv_file]                # Exportar CSV
```

### Scheduler

```bash
brainx-v2 schedule add <name> <cron> <agent> <cmd> # Agregar tarea
brainx-v2 schedule list                            # Listar tareas
brainx-v2 schedule run <id>                        # Ejecutar ahora
brainx-v2 schedule remove <id>                     # Eliminar
brainx-v2 schedule toggle <id>                     # Habilitar/deshabilitar
brainx-v2 schedule sync                            # Generar crontab
```

### Webhooks

```bash
brainx-v2 webhook register <name> <url> <event>    # Registrar webhook
brainx-v2 webhook list                             # Listar
brainx-v2 webhook trigger <id> <payload>           # Trigger manual
brainx-v2 webhook remove <id>                      # Eliminar
brainx-v2 webhook test <id>                        # Probar
brainx-v2 webhook logs                             # Ver logs
```

### Auditoría

```bash
brainx-v2 audit query [agent] [type] [limit]       # Query logs
brainx-v2 audit activity <agent> [days]            # Reporte actividad
brainx-v2 audit security                           # Reporte seguridad
brainx-v2 audit stats                              # Estadísticas
brainx-v2 audit cleanup [days]                     # Limpiar viejos
```

### Sistema

```bash
brainx-v2 agents                                   # Listar agentes
brainx-v2 stats                                    # Estadísticas
brainx-v2 health                                   # Health check
brainx-v2 help                                     # Ayuda
```

---

## 🚀 Optimizaciones de Costo

### Pipeline de Optimización

```
Query → [Response Cache?] → Search Memories → [Semantic Dedup] →
Filter → Build Context → [Local Prune] → [Compress] →
[Semantic Compress] → [Progressive Summarize] → Format → LLM
```

### Ahorros Estimados

| Optimización | Reducción |
|--------------|-----------|
| Response Caching | 20-40% |
| Semantic Dedup | 10-25% |
| Local Compression | 30-50% |
| Progressive Summarization | 40-60% |
| **Total** | **50-70%** |

### Configuración

```bash
# Compresión semántica
SEMANTIC_COMPRESS=true
COMPRESS_THRESHOLD=5000
COMPRESS_RATIO=0.4

# Cache de respuestas
RESPONSE_CACHE_ENABLED=true
SEMANTIC_CACHE=true
CACHE_TTL=3600
SIMILARITY_THRESHOLD=0.85

# Compresión local (Ollama)
LOCAL_COMPRESS_ENABLED=true
LOCAL_MODEL=llama3.2-32k:latest
LOCAL_MAX_TOKENS=2000
OLLAMA_HOST=http://localhost:11434

# Summarization
SUMMARIZER_ENABLED=true
SUMMARIZE_AFTER_N=10
SUMMARY_MAX_TOKENS=300
KEEP_MESSAGES_AFTER_SUMMARY=5

# Deduplicación
DEDUP_ENABLED=true
DEDUP_METHOD=hybrid
SIMILARITY_THRESHOLD=0.85
```

---

## 🔌 Integración OpenClaw

### Agentes Configurados

| Agent | Modelo | Propósito |
|-------|--------|-----------|
| main (Jarvis) | zai/glm-5 | Coordinador principal |
| coder | openrouter/moonshotai/kimi-k2.5 | Refactoring largo |
| writer | anthropic/claude-opus-4-6 | Contenido largo |
| researcher | google-gemini-cli/gemini-2.5-pro | Investigación profunda |
| clawma | zai/glm-4.7 | Análisis costo-eficiente |
| reasoning | openai-codex/gpt-5.2 | Problemas estratégicos |
| support | minimax-portal/MiniMax-M2.5 | Soporte general |
| heartbeat | ollama/llama3.2:1b | Monitoreo de salud |

### Arquitectura Multi-Agent

```
~/.openclaw/
├── workspace/                    # Storage central
│   ├── memory/                   # Memoria unificada
│   ├── .memory-system/           # Storage JSONL
│   └── SESSION_INIT_RULE.md      # Reglas de sesión
│
├── workspace-{agent}/            # Workspaces por agent
│   ├── memory → ../workspace/memory/     # Symlink
│   └── SESSION_INIT_RULE.md → ../workspace/SESSION_INIT_RULE.md
│
└── agents/{agent}/               # Config OpenClaw
    └── brainx-wrapper/           # Wrapper con hooks
        ├── agent-wrapper         # Script principal
        └── config.sh             # BRAINX_CENTRAL_ENABLED=true
```

### Wrapper de Agente

```bash
# Configuración del wrapper
BRAINX_CENTRAL_ENABLED="true"
BRAINX_AGENT_ID="main"
BRAINX_AGENT_NAME="@main"
```

### Funciones del Wrapper

```bash
# Hooks de sesión
session_start "contexto"
session_decision "acción" "razón" [importancia]
session_action "descripción" "resultado" "tags"
session_learning "patrón" "lección" "fuente"
session_gotcha "problema" "solución" "severidad"
session_end "resumen"

# Acceso a memoria
inject_context "query"
search_memory "query"
```

---

## 💾 Storage

### Estructura

```
.memory-system/
├── storage/
│   └── memories.jsonl        # Todas las memorias
├── indexes/
│   └── memory-index.json     # Índice de búsqueda
├── hooks/
│   └── agent-hook.sh         # Hook script
└── backup/
    └── *.backup              # Backups automáticos
```

### Formato de Entrada

```json
{
  "id": "mem_20260209_a1b2c3d4",
  "type": "decision",
  "content": "Chose PostgreSQL over MongoDB",
  "context": "backend-architecture",
  "tier": "hot",
  "agent": "main",
  "timestamp": "2026-02-09T15:30:00Z",
  "importance": 8
}
```

### Tipos de Entrada

| Tipo | Descripción |
|------|-------------|
| decision | Decisiones técnicas |
| action | Acciones realizadas |
| learning | Aprendizajes |
| gotcha | Problemas y workarounds |
| note | Notas generales |

---

## 📊 Features por Versión

### v2.1.0 (Actual)

- ✅ HTTP Client con connection pooling
- ✅ Context Optimizer
- ✅ Compresión semántica
- ✅ Cache de respuestas
- ✅ Compresión local con Ollama
- ✅ Summarization progresiva
- ✅ Deduplicación semántica
- ✅ 28 librerías funcionales

### v2.0.0

- ✅ Métricas de tokens y costo
- ✅ Scheduler distribuido
- ✅ Webhooks
- ✅ Auditoría completa
- ✅ Sistema unificado

---

## 🛠️ Instalación

### Requisitos

```bash
# Dependencias
sudo apt-get install jq bc curl

# Ollama (opcional, para compresión local)
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.2-32k:latest
```

### Setup

```bash
# Clonar
git clone https://github.com/Mdx2025/brainx-v2.git
cd brainx-v2

# Verificar
./brainx-v2 health
./brainx-v2 local-health  # Si usas Ollama
```

### Integración con OpenClaw

```bash
# Crear config por agente
for agent in main coder writer researcher clawma support reasoning; do
  cat > ~/.openclaw/agents/$agent/brainx-wrapper/config.sh <<EOF
BRAINX_CENTRAL_ENABLED="true"
BRAINX_AGENT_ID="$agent"
BRAINX_AGENT_NAME="@$agent"
EOF
done

# Crear symlinks de memory
for agent in clawma coder heartbeat main projects reasoning researcher support writer; do
  ln -sf /home/clawd/.openclaw/workspace/memory ~/.openclaw/workspace-$agent/memory
  ln -sf /home/clawd/.openclaw/workspace/SESSION_INIT_RULE.md ~/.openclaw/workspace-$agent/SESSION_INIT_RULE.md
done
```

---

## 📝 Documentación

| Archivo | Propósito |
|---------|-----------|
| `README.md` | Overview general |
| `ARCHITECTURE.md` | Arquitectura del sistema |
| `DEPLOY.md` | Guía de deploy OpenClaw |
| `OPTIMIZATIONS.md` | Optimizaciones de costo |
| `CHANGELOG.md` | Historial de cambios |
| `MEMORY.md` | Sistema de memoria |
| `SKILL.md` | Definición como skill |

---

## 🔗 Links

- **Repo:** https://github.com/Mdx2025/brainx-v2
- **OpenClaw docs:** https://docs.openclaw.ai
- **Community:** https://discord.com/invite/clawd

---

*Auto-generado: 2026-02-14*
