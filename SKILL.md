# BrainX V2 Skill

> **Versión:** v2.2.0 (Production) - 2026-02-13
> **Ubicación:** `/home/clawd/.openclaw/workspace/skills/brainx-v2/`
> **Estado:** ✅ Production Ready

## Descripción General

BrainX V2 es el sistema unificado de inteligencia de memoria e optimización de contexto para OpenClaw. Integra gestión de memoria, RAG, optimización de tokens y **auto-inyección de entidades** en un solo CLI.

## Características Principales

### 🧠 Memoria Unificada
- **Almacenamiento en tiers**: HOT (crítico), WARM (activo), COLD (archivado)
- **Búsqueda semántica**: RAG con scoring de relevancia
- **Hooks de agentes**: Auto-registro de decisiones, acciones, aprendizajes
- **Auto-extracción**: Plugin memory-inyection detecta y guarda automáticamente

### ⚡ Optimización de Contexto
- **Compresión de prompts**: Reduce tokens 40-60%
- **Conteo de tokens**: Tiktoken + fallback
- **Truncación inteligente**: Mantiene bajo presupuesto
- **Relevance Scoring**: Filtra contexto irrelevante
- **Prompt Caching**: 90% descuento en cache hits

### 🔗 Integración OpenClaw (NUEVO v2.2)
- **memory-inyection**: Plugin que auto-detecta emails, URLs, GitHub, finanzas, errores
- **openclaw-memory-hook.sh**: Unificador de recall/inject con fallbacks
- **Pipeline unificado**: BrainX V2 → Lightweight Recall → grep+jq fallback

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

## Integración con Memory-Inyection (NUEVO)

El plugin `memory-inyection` detecta automáticamente entidades en mensajes entrantes y las guarda en BrainX V2 storage.

### Entidades Auto-Detectadas
| Tipo | Patrón | Tier |
|------|--------|------|
| Email | `user@domain.com` | warm |
| GitHub | `github.com/user/repo` | cold |
| Finanzas | `$100`, `€50`, `BTC 0.5` | hot |
| Errores | Stacktraces | hot |
| Secrets | API keys (redacted) | hot |
| URLs | `https://...` | cold |
| Fechas | `2024-01-15`, `deadline` | warm |

### Plugin Location
```
/home/clawd/.openclaw/extensions/memory-inyection/
```

### Uso del Unificador
```bash
source /home/clawd/.openclaw/workspace/skills/brainx-v2/openclaw-memory-hook.sh

# Recall con fallbacks automáticos
openclaw_recall "database config"

# Inyectar contexto formateado
openclaw_inject_context "railway deployment" 5

# Checkpoint de sesión
openclaw_checkpoint "working on emailbot"

# Ver estado del sistema
openclaw_memory_status
```

### Arquitectura de Integración
```
Mensaje entrante
      │
      ▼
┌─────────────────────┐
│  memory-inyection   │ ← Plugin OpenClaw
│  (auto-detect)      │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│   BrainX V2         │ ← Storage unificado
│   storage/{tier}/   │   Hot/Warm/Cold
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ openclaw-memory-    │ ← Unificador
│ hook.sh             │   Con fallbacks
└─────────┴───────────┘
          │
    ┌─────┴─────┐
    ▼           ▼
 BrainX      Lightweight
 inject      recall
 (full)      (grep+jq)
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
