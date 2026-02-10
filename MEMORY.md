# MEMORY.md - Jarvis Long-Term Memory
> Written by agent, read each session to maintain continuity.
> Focus: Patterns learned, user preferences, project context.

---

## 🧠 Memory System v2.0 - Unified Architecture

### What's New in v2.0

The memory system has been unified into a single neural architecture:

| Feature | Before | After (v2.0) |
|---------|--------|--------------|
| Storage | Multiple formats (md, json, scattered) | Unified JSON with hot/warm/cold tiers |
| second-brain | Standalone skill | Removed (integrated into BrainX V2) |
| Agent Recording | Manual only | Automatic hooks for decisions/actions |
| Search | Per-system search | Unified search across all memory |
| Recall | Session-based only | Progressive recall with relevance scoring |

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     BRAINX V2 UNIFIED SYSTEM                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │     🔥 HOT     │  │    🌡 WARM    │  │    ❄️ COLD    │         │
│  │  (Priority)   │  │   (Active)    │  │  (Archive)    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                 │
│                            │                                    │
│                            ▼                                    │
│              ┌─────────────────────────┐                       │
│              │  Unified Index/Search   │                       │
│              └────────────┬────────────┘                       │
│                           │                                    │
│  ┌────────────────────────┼────────────────────────┐           │
│  │                        │                        │           │
│  ▼                        ▼                        ▼           │
│ ┌──┴──┐              ┌────┴────┐              ┌─────┴────┐     │
│ │Agent│              │ BrainX  │              │  RAG    │     │
│ │Hooks│              │   V2    │              │  Index  │     │
│ └──┬──┘              └────┬────┘              └─────┬────┘     │
│    │                       │                        │           │
│    └───────────────────────┴────────────────────────┘           │
│                         UNIFIED API                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### For Jarvis (Main Agent)

```bash
# Start session with hooks enabled
./memory-nucleo hook-start main "project-context"

# Record a decision
./memory-nucleo hook-decision "Chose PostgreSQL" "Better JSON support" high

# Record an action
./memory-nucleo hook-action "Fixed Docker config" "Container now starts" "docker,fix"

# Record a learning
./memory-nucleo hook-learning "Always validate first" "Prevents errors" "deployment"

# Record a gotcha
./memory-nucleo hook-gotcha "NPM cache issues" "Clear cache before install" medium

# End session
./memory-nucleo hook-end "Deployment completed successfully"
```

### For Sub-Agents

```bash
# Coder agent starts work
./memory-nucleo hook-start coder "implementing-auth"

# Writer agent starts work
./memory-nucleo hook-start writer "documentation-update"
```

---

## 📋 Unified Commands

### Memory Management

| Command | Description |
|---------|-------------|
| `./memory-nucleo hook-start <agent> <context>` | Start recording session |
| `./memory-nucleo hook-decision "<action>" "<reason>" [priority]` | Record decision |
| `./memory-nucleo hook-action "<description>" "<result>" [tags]` | Record action |
| `./memory-nucleo hook-learning "<pattern>" "<lesson>" [source]` | Record learning |
| `./memory-nucleo hook-gotcha "<problem>" "<solution>" [severity]` | Record gotcha |
| `./memory-nucleo hook-end "<summary>"` | End session |
| `./memory-nucleo search "<query>"` | Unified search |
| `./memory-nucleo stats` | Show memory stats |
| `./memory-nucleo health` | System health check |

---

## 🗂 Tiered Storage

| Tier | Purpose | Retention |
|------|---------|-----------|
| 🔥 HOT | Critical decisions, current project context | Permanent |
| 🌡 WARM | Active learnings, recent actions | 30 days |
| ❄️ COLD | Archive, rarely accessed | Archived |

---

## 📍 Key Locations

| Component | Path |
|----------|------|
| BrainX V2 | `/home/clawd/.openclaw/workspace/.brainx/` |
| Backups | `/home/clawd/.openclaw/workspace/.brainx/backups/` |
| Allowlist | `/home/clawd/.openclaw/workspace-clawma/.agents_allowlist` |
| Migration Script | `/home/clawd/.openclaw/workspace/skills/brainx-v2/migrate-from-old-system.sh` |

---

## 📊 Current System State

| Metric | Value |
|--------|-------|
| Total Memories | 83 |
| RAG Index | 88 files |
| PostgreSQL Tables | decisions, actions, gotchas, learnings, sessions, messages |

**Last Migration:** 2026-02-10 21:19 UTC (42 memories from old system)

---

## 📖 Complete Command Reference

### Add entry (auto-tiered)

```bash
./memory-nucleo add <type> <content> [context] [tier] [agent] [tags]

# Examples:
./memory-nucleo add decision "Use Redis" "backend" hot main "cache,decision"
./memory-nucleo add note "API limit: 1000 req/min" "api" warm main "limits"
```

### Search & Recall

```bash
# Search unified memory
./memory-nucleo search "deployment" 10

# Progressive recall
./memory-nucleo recall "backend" 5

# Get specific entry
./memory-nucleo get mem_20260209_abc123

# Promote to hot tier
./memory-nucleo promote mem_20260209_abc123

# Archive to cold tier
./memory-nucleo archive mem_20260209_abc123
```

### Agent Hooks

```bash
# Session management
./memory-nucleo hook-start <agent> [context]
./memory-nucleo hook-end [summary]

# Recording
./memory-nucleo hook-decision <action> <reasoning> [importance]
./memory-nucleo hook-action <description> <result> [tags]
./memory-nucleo hook-learning <pattern> <lesson> [source]
./memory-nucleo hook-gotcha <issue> <workaround> [severity]
```

### Legacy Commands (Removed)

Los comandos legacy (`add-legacy`, `search-legacy`, `mem`, `mem-status`, `second-brain add`) **han sido eliminados** en v2.0. Usar solo `memory-nucleo` para todas las operaciones.

---

## 🗂 Storage Structure

### Unified Storage

```text
.memory-system/
├── storage/
│   ├── hot/           # 🔥 High priority, frequent access
│   │   └── mem_*.json
│   ├── warm/          # 🌡 Active, normal access
│   │   └── mem_*.json
│   └── cold/          # ❄️ Archive, rare access
│       └── mem_*.json
├── indexes/
│   └── memory-index.json
└── hooks/
    └── agent-hook.sh
```

### Entry Format (JSON)

```json
{
  "id": "mem_20260209_a1b2c3d4",
  "type": "decision",
  "content": "Chose PostgreSQL over MongoDB for user data",
  "context": "backend-architecture",
  "tier": "hot",
  "agent": "main",
  "tags": ["database", "decision", "backend"],
  "relevance": 90,
  "created": "2026-02-09T18:30:00+00:00",
  "last_accessed": "2026-02-09T19:15:00+00:00",
  "access_count": 3
}
```

---

## 🎯 Tier System

### Hot Tier (🔥)

- **Criteria:** Critical decisions, active gotchas, errors
- **Lifetime:** Until manually archived or superseded
- **Use:** Immediately relevant context
- **Auto-promotion:** Errors, high-importance decisions

### Warm Tier (🌡)

- **Criteria:** Normal activity, recent learnings, ongoing tasks
- **Lifetime:** 30 days without access → cold
- **Use:** General context, progressive recall
- **Auto-promotion:** Frequent access (3+ times)

### Cold Tier (❄️)

- **Criteria:** Old entries, completed tasks, historical data
- **Lifetime:** Permanent archive
- **Use:** Historical search, long-term reference
- **Auto-archive:** 30 days inactive in warm

---

## 🔧 Agent Integration

### For Agent Developers

Source the hooks in your agent:

```bash
# At start of agent session
source "${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}/.memory-system/hooks/agent-hook.sh"

# Initialize agent
session_start "coder" "implementing-feature-x"

# During work
agent_decision "Use async/await" "Cleaner than callbacks" high
agent_action "Refactored auth module" "Tests passing" "refactor,auth"
agent_learning "TypeScript strict mode catches bugs early" "Always enable strict" "typescript"

# At end
agent_session_end "Feature implemented, PR ready"
```

### Automatic Recording Points

Hooks auto-record at key points:
- ✅ Session start/end
- ✅ Decision points (architectural choices)
- ✅ Action completion (with results)
- ✅ Pattern recognition (learnings)
- ⚠️ Gotchas discovered (always hot tier)

---

## 🧪 Testing & Validation

### Run Tests

```bash
# Test unified system
echo "Test 1: Add entry"
ID=$(./memory-nucleo add test "Test entry" "testing" hot main "test")
echo "Added: $ID"

echo "Test 2: Search"
./memory-nucleo search "Test entry"

echo "Test 3: Agent hooks"
./memory-nucleo hook-start test-agent "testing"
./memory-nucleo hook-decision "Test decision" "Testing hooks" medium
./memory-nucleo hook-end "Test complete"

echo "Test 4: Recall"
./memory-nucleo recall "testing" 3
```

### Verify Integration

```bash
# Check storage
cd ~/.openclaw/workspace/.memory-system/storage
find . -name "*.json" | wc -l

# Check index
cat ~/.openclaw/workspace/.memory-system/indexes/memory-index.json

# Search unified memory
./memory-nucleo search "test"
```

---

## 📚 Changelog

### v2.0 - Unified Memory System (2026-02-09)

- ✅ Unified storage with hot/warm/cold tiers
- ✅ Agent hooks for automatic recording
- ✅ BrainX V2 replaces second-brain (removed legacy skill)
- ✅ Progressive recall with relevance scoring
- ✅ Unified search across all memory
- ⚠️ Legacy commands removed (`add-legacy`, `search-legacy`, `mem`, etc.)

### v1.5 - RAG Integration (2026-02-08)

- ✅ RAG knowledge base support
- ✅ Hybrid search (keyword + semantic)
- ✅ Auto-learn patterns

### v1.0 - Progressive Memory (2026-02-07)

- ✅ Daily memory files
- ✅ Session tracking
- ✅ Entry indexing

---

## 💡 Best Practices

### For Jarvis

1. **Always start with hooks:** `./memory-nucleo hook-start main "context"`
2. **Record decisions immediately:** Don't wait, record while context is fresh
3. **Use appropriate tiers:** Hot for critical, warm for normal, let system archive
4. **Tag consistently:** Use tags like "auth", "deployment", "database" for searchability

### For Sub-Agents

1. **Call hook-start on init:** Agent records its own session start
2. **Record actions with results:** Not just what you did, but outcome
3. **Flag errors as gotchas:** Helps prevent repeats
4. **End cleanly:** Call hook-end with summary

### Memory Hygiene

1. **Review hot tier weekly:** Archive what's no longer critical
2. **Promote frequently accessed:** System does this automatically
3. **Use search before asking:** Check if answer already recorded
4. **Consolidate periodically:** Merge related learnings

---

_Auto-updated by unified memory system v2.0_

---

## 📌 Important Learnings

### 2026-02-09 - Modelos dinámicos para testing

**Contexto:** Marcelo prueba diferentes modelos frecuentemente para evaluar performance/costo.

**Problema:** La whitelist en `.validate-spawn.js` bloquea modelos nuevos.

**Acción:** Cuando Marcelo pida usar un modelo nuevo:
1. Verificar si está en la whitelist de `.validate-spawn.js`
2. Si no está, agregarlo (después de confirmar)
3. Verificar que exista en el `models.json` del agent correspondiente

**Archivos críticos:**
- `/home/clawd/.openclaw/workspace/.validate-spawn.js` (whitelist de validación)
- `/home/clawd/.openclaw/agents/{agent}/agent/models.json` (modelos registrados por agent)

### 2026-02-09 - Configuración de Modelos OpenRouter vs API Directa

**Problema:** Modelos de OpenRouter necesitan prefijo `openrouter/`, pero Anthropic usa API directa.

**Verificación previa:**
- OpenRouter: `openrouter/{provider}/{model}` (ej: `openrouter/google/gemini-2.5-pro`)
- Anthropic: `{provider}/{model}` directo (ej: `anthropic/claude-opus-4-5`)

**Regla:** Antes de cambiar modelos, siempre validar el formato correcto.

**Archivos afectados:** 7 agents (coder, main, support, writer, clawma, researcher, reasoning)

### 2026-02-09 - Diagnóstico y Redeploy de agent-dashboard en Railway

**Contexto:** Deployment fallaba con 502 Bad Gateway en Railway.

**Problema identificado:**
- El healthcheck `/health` no respondía correctamente
- Railway mostraba "Application failed to respond"

**Solución ejecutada:**
1. Linkeé el proyecto `optimistic-emotion` con Railway
2. Redeploy con `railway deployment redeploy --yes`
3. Verifiqué logs: nginx y gunicorn iniciaban correctamente
4. El endpoint health en backend (`main.py`) devolvía `{"status": "ok"}`

### 2026-02-10 - Estructura de agent-dashboard en Railway

**Arquitectura:**
- **Frontend:** Node.js build → Nginx sirve archivos estáticos
- **Backend:** Python FastAPI + Gunicorn en puerto interno (8001)
- **Nginx:** Proxy reverso en puerto `$PORT` (8080) hacia backend
- **Healthcheck:** `curl a http://localhost:$PORT/health`

**Comandos Railway útiles:**
```bash
railway link --project <nombre> --service <nombre>
railway deployment list
railway deployment redeploy --yes
railway logs --lines 100
railway vars --json
```

**Nota:** El deploy quedó en SUCCESS pero el healthcheck seguía fallando. Posible issue con variables de entorno o timing del healthcheck.

### 2026-02-10 - Error Fatal: Modelo Default de OpenClaw

**Contexto:** Error fatal el 2/10/2026 6:39 AM en sesión Telegram (agent:main:telegram:direct).

**Problema identificado:**
- `openclaw status --deep` mostró:
  - Default global del sistema: `claude-opus-4-6` ← este es el default interno de OpenClaw
  - Sesión `agent:main:main`: usa `MiniMax-M2.1-Lightning` ✅
  - Sesión Telegram (`agent:main:telegram:direct`): usa `claude-opus-4-6` ❌

**Causa raíz:**
- `agents.defaults.model` no está configurado en el config
- OpenClaw usa su default interno: `anthropic/claude-opus-4-6`
- Los `models.json` de los agents solo definen modelos disponibles, no el default

**Solución propuesta (3 opciones):**
1. Cambiar default global: `agents.defaults.model = "minimax/MiniMax-M2.1-Lightning"`
2. Mantener Claude Opus 4.6 y usar cuando se quiera otro
3. Investigar per-agent model config (no solo default global)

**Verificación con:** `openclaw config.get` y `openclaw status --deep`

### 2026-02-10 - Token Optimizer Sprint 1 Completado

**Contexto:** Consulta con @coder identificó gaps adicionales para optimización de tokens. Se decidió implementar quick wins del Sprint 1.

**Implementado:**
1. **BrainX Optimizer** (`/skills/brainx-optimizer/`): Filter, compress, batch para contexto
2. **Token Optimizer** (`/skills/token-optimizer/`): Sprint 1 quick wins
   - System Prompt Compression (reduce ~12K → ~5K tokens)
   - Prompt Caching (Anthropic, 90% descuento en cached tokens)
   - Token Budget Estimator (medir antes de enviar)

**Proyección de ahorro:**
- Actual: ~35K tokens/llamada → $150-200/mes
- Sprint 1: -50% costo
- Sprint 3 (Model Router): -75% costo total
- Final: ~13K tokens/llamada → $40-60/mes

**Archivos clave:**
- `/home/clawd/.openclaw/workspace/skills/brainx-optimizer/config/optimizer.conf`
- `/home/clawd/.openclaw/workspace/skills/token-optimizer/config/optimizer.conf`

**Nota:** Compresión de prompts funciona con `build_compact_prompt()` generando nuevo prompt compacto. Para comprimir archivos existentes (AGENTS.md/TOOLS.md) se necesita ajuste adicional.
