# OpenClaw Session Management - Session Keys

**Fuente:** https://docs.openclaw.ai/reference/session-management-compaction

## Session Keys (sessionKey)

Identifica el "bucket" de conversación (routing + isolation).

### Patrones Comunes

| Pattern | Descripción | Ejemplo |
|---------|-------------|---------|
| `agent:<agentId>:<mainKey>` | Chat principal/directo (por agent) | `agent:clawma:main` |
| `agent:<agentId>:group:<id>` | Grupo | `agent:clawma:group:123` |
| `agent:<agentId>:channel:<id>` | Canal (Discord/Slack) | `agent:clawma:channel:general` |
| `agent:<agentId>:room:<id>` | Sala/ROOM | `agent:clawma:room:456` |
| `cron:<jobId>` | Cron jobs | `cron:heartbeat-1` |
| `hook:<uuid>` | Webhooks | `hook:a1b2c3d4` |

### Valor por Defecto

- `agent::` (sin mainKey) = chat principal

---

## Session Ids (sessionId)

Cada sessionKey apunta a un sessionId (archivo de transcript).

### Cuándo se crea uno nuevo:

1. **Reset manual** (`/new`, `/reset`) → nuevo sessionId
2. **Reset diario** (default 4:00 AM) → nuevo sessionId en el siguiente mensaje
3. **Idle expiry** → nuevo sessionId después del idle window

---

## Dos Capas de Persistencia

### 1. Session Store (`sessions.json`)
- **Ubicación:** `~/.openclaw/agents/<agentId>/sessions/sessions.json`
- Key/Value: `sessionKey` → `SessionEntry`
- Mutable, seguro de editar
- **Campos importantes:**
  - `sessionId` - transcript actual
  - `updatedAt` - timestamp
  - `chatType` - direct | group | room
  - Token counters (input/output/total/context)
  - `compactionCount` - veces que hizo auto-compact
  - `memoryFlushAt` - último flush de memoria

### 2. Transcripts (`*.jsonl`)
- **Ubicación:** `~/.openclaw/agents/<agentId>/sessions/.jsonl`
- Estructura JSONL con tree (id + parentId)
- **Tipos de entries:**
  - `message` - user/assistant/tool results
  - `custom_message` - entra en context (puede ocultarse de UI)
  - `custom` - no entra en context
  - `compaction` - resumen de compactación
  - `branch_summary` - resumen de branch

---

## Compaction

Resume conversación vieja en un entry persistido.

### Cuándo ocurre:
1. **Overflow recovery** - context overflow error → compact → retry
2. **Threshold maintenance** - contextTokens > contextWindow - reserveTokens

### Settings (Pi runtime):
```json
{
  "compaction": {
    "enabled": true,
    "reserveTokens": 16384,
    "keepRecentTokens": 20000
  }
}
```

### Memory Flush (Pre-compaction)
Antes de compactar, escribe memoria a disk para no perder contexto crítico.

**Config:** `agents.defaults.compaction.memoryFlush`
- `enabled` (default: true)
- `softThresholdTokens` (default: 4000)

---

## Silent Housekeeping (NO_REPLY)

Para tasks de fondo donde el usuario no debe ver output:

- Starts output con `NO_REPLY` → no se entrega al usuario
- OpenClaw strippea esto en la delivery layer
- Desde 2026.1.10: también suprime typing streaming

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| Session key wrong | Verificar con `/status` |
| Store vs transcript mismatch | Confirmar Gateway host y path |
| Compaction spam | Revisar context window, reserveTokens, tool-result bloat |
| Silent turns leak | Confirmar que reply empieza con `NO_REPLY` exacto |

---

## Comandos Útiles

```bash
openclaw status              # Ver estado general
openclaw sessions --json     # Lista de sesiones
/status                       # En cualquier chat
```

## Ver También

- [/concepts/session](/concepts/session)
- [/concepts/compaction](/concepts/compaction)
- [/concepts/session-pruning](/concepts/session-pruning)
- [/reference/transcript-hygiene](/reference/transcript-hygiene)
- [/token-use](/reference/token-use)
