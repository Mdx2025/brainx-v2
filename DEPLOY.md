# BrainX V2 Deployment Guide

## OpenClaw Multi-Agent Deploy (2026-02-13)

### Arquitectura

```
~/.openclaw/
├── workspace/                    # Main workspace (storage central)
│   ├── memory/                   # Storage unificado
│   │   ├── MEMORY.md
│   │   ├── archive/
│   │   └── daily/
│   └── SESSION_INIT_RULE.md
│
├── workspace-{agent}/            # Workspaces por agent
│   ├── memory -> ../workspace/memory/     # Symlink a storage
│   ├── MEMORY.md                          # Contexto específico del agent
│   └── SESSION_INIT_RULE.md -> ../workspace/SESSION_INIT_RULE.md
│
└── agents/{agent}/               # Config OpenClaw
```

### Agents Configurados

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
| projects | (varios) | Gestión de proyectos |

---

## Proceso de Deploy

### Fase 1: Limpieza de Duplicados

```bash
# Detectar duplicados
./lib/dedup.sh --find

# Output ejemplo:
# Found 127 potential duplicates

# Limpiar duplicados de MEMORY.md
# Resultado: 2,686 líneas → 1,903 líneas (-29%)
```

### Fase 2: Validación de Archivos

```bash
# Verificar integridad
find ~/.openclaw/workspace/memory -name "*.md" -exec sh -c '
  for f; do
    if ! head -1 "$f" | grep -q "^#"; then
      echo "CORRUPT: $f"
    fi
  done
' sh {} +

# Resultado esperado: 0 archivos corruptos
```

### Fase 3: Symlinks y Consistencia

```bash
# Crear symlinks de memory para todos los agents
for ws in clawma coder heartbeat main projects reasoning researcher support writer; do
  target="$HOME/.openclaw/workspace-$ws"
  ln -sf /home/clawd/.openclaw/workspace/memory "$target/memory"
done

# Crear symlinks de SESSION_INIT_RULE.md
for ws in clawma coder heartbeat main projects reasoning researcher support writer; do
  target="$HOME/.openclaw/workspace-$ws"
  ln -sf /home/clawd/.openclaw/workspace/SESSION_INIT_RULE.md "$target/SESSION_INIT_RULE.md"
done
```

**Nota:** MEMORY.md se deja como archivo propio por agent (contexto específico).

---

## Comunicación Inter-Agent

### Leer contexto de otro agent

```bash
# Desde cualquier agent
read("~/.openclaw/workspace-{agent}/MEMORY.md")
```

### Enviar mensaje directo

```bash
# Requiere sesión activa del agente destino
sessions_send(sessionKey="agent:main:xxx", message="¿Puedes revisar X?")
```

### Delegar tarea

```bash
# Spawnea sub-agent y devuelve resultado
sessions_spawn(agentId="researcher", task="Investigar X tema")
```

---

## Memory Tiers

| Tier | Criterio | Lifetime | Uso |
|------|----------|----------|-----|
| 🔥 Hot | Decisiones críticas, errores activos | Permanente | Contexto inmediato |
| 🌡️ Warm | Actividad normal, learnings recientes | 30 días → cold | Contexto general |
| ❄️ Cold | Entradas antiguas, histórico | Permanente | Referencia histórica |

---

## BrainX Memory Guardian

El Guardian protege automáticamente la memoria:

```bash
# Iniciar guardian
./brainx-memory-guardian.sh start

# Verificar estado
./brainx-memory-guardian.sh status

# Backup manual
./brainx-memory-guardian.sh backup

# Restaurar
./brainx-memory-guardian.sh restore <backup-id>
```

---

## Optimizaciones Disponibles

### Librerías en `lib/`

| Script | Función |
|--------|---------|
| `counter.sh` | Estadísticas de entradas |
| `dedup.sh` | Detectar/remover duplicados |
| `local_compressor.sh` | Compresión de contexto |
| `optimizer.sh` | Optimización global |
| `relevance.sh` | Scoring de relevancia |
| `summarizer.sh` | Resumir entradas |
| `truncator.sh` | Truncado inteligente |

### Uso típico

```bash
# Optimización mensual
./lib/optimizer.sh --full

# Buscar entradas relevantes
./lib/relevance.sh --top --query "api" --limit 5
```

---

## Troubleshooting

### Symlinks rotos

```bash
# Verificar symlinks
for ws in clawma coder heartbeat main projects reasoning researcher support writer; do
  ls -la ~/.openclaw/workspace-$ws/memory
done

# Recrear si es necesario
ln -sf /home/clawd/.openclaw/workspace/memory ~/.openclaw/workspace-{agent}/memory
```

### Memory corrupta

```bash
# Restaurar desde backup
./brainx-memory-guardian.sh restore latest
```

### Agent no ve memory

```bash
# Verificar que el symlink apunta al storage central
readlink ~/.openclaw/workspace-{agent}/memory
# Debe retornar: /home/clawd/.openclaw/workspace/memory
```

---

## Checklist Post-Deploy

- [ ] Symlinks de `memory/` creados (9/9 agents)
- [ ] Symlinks de `SESSION_INIT_RULE.md` creados (9/9 agents)
- [ ] MEMORY.md propio por agent (contexto específico)
- [ ] Guardian activo (`./brainx-memory-guardian.sh status`)
- [ ] Sin duplicados (`./lib/dedup.sh --find` = 0)
- [ ] Optimización inicial ejecutada (`./lib/optimizer.sh --full`)

---

## Referencias

- **Repo:** https://github.com/Mdx2025/brainx-v2
- **Docs locales:** `OPTIMIZATIONS.md`, `brainx-v2-reference.md`
- **OpenClaw docs:** https://docs.openclaw.ai
