# BrainX V2 + OpenClaw Integration Guide

## Problema Resuelto

BrainX V2 es un CLI standalone que necesita integración manual con OpenClaw.
Esta solución crea un **wrapper update-safe** que sobrevive a reinstalaciones/updates.

## Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│  OpenClaw Agent (cualquiera: claude, gemini, etc.)         │
│            ↓                                               │
│  source brainx-wrapper/agent-wrapper                        │
│            ↓                                               │
│  BrainX V2 hooks: session_start, decision, action, etc.   │
│            ↓                                               │
│  Memorias persistentes en /workspace/skills/brainx-v2/     │
└─────────────────────────────────────────────────────────────┘
```

## Instalación (Una sola vez)

### Opción 1: En tu workspace (recomendado)

```bash
cd /home/clawd/.openclaw/workspace-clawma

# Ya está creado en:
ls -la brainx-wrapper/
```

### Opción 2: En tu HOME (si querés global)

```bash
mkdir -p ~/bin
cp brainx-wrapper/agent-wrapper ~/bin/brainx-agent
chmod +x ~/bin/brainx-agent
export PATH="$HOME/bin:$PATH"
```

## Uso

### Desde la terminal (sesión interactiva)

```bash
source /home/clawd/.openclaw/workspace-clawma/brainx-wrapper/agent-wrapper

# Iniciar sesión
session_start "claude" "trabajando en proyecto X"

# Registrar decisiones
session_decision "Usar PostgreSQL" "Porque necesitamos ACID" 8

# Registrar acciones
session_action "Configuré DB" "completado" "database,setup"

# Registrar aprendizajes
session_learning "pattern: reintentos" "siempre implementar retry con backoff"

# Finalizar sesión
session_end "proyecto X completado"

# Buscar en memorias
search_memory "PostgreSQL"

# Obtener contexto para una query
inject_context "cómo configuro la base de datos"
```

### En scripts de agentes

```bash
#!/bin/bash
source /home/clawd/.openclaw/workspace-clawma/brainx-wrapper/agent-wrapper

# Inicializar
session_start "mi-script" "backup automation"

# Tu lógica
if [ "$respuesta" == "error" ]; then
    session_gotcha "API timeout" "Reintentar 3 veces con backoff exponencial" "high"
fi

# Finalizar
session_end "backup completado"
```

## Integración con Agentes Específicos

### Para Claude Code CLI

```bash
# Crear wrapper para claude
cat > /usr/local/bin/claude-brainx << 'EOF'
#!/bin/bash
source /home/clawd/.openclaw/workspace-clawma/brainx-wrapper/agent-wrapper
session_start "claude-code" "$@"
exec claude "$@"
session_end "sesión claude-code terminada"
EOF
chmod +x /usr/local/bin/claude-brainx
```

### Para Gemini CLI

```bash
cat > /usr/local/bin/gemini-brainx << 'EOF'
#!/bin/bash
source /home/clawd/.openclaw/workspace-clawma/brainx-wrapper/agent-wrapper
session_start "gemini" "$@"
exec gemini "$@"
session_end "sesión gemini terminada"
EOF
chmod +x /usr/local/bin/gemini-brainx
```

## Verificar que funciona

```bash
# Ver logs
tail -f /home/clawd/.openclaw/workspace-clawma/brainx-wrapper/logs/wrapper.log

# Health check
source /home/clawd/.openclaw/workspace-clawma/brainx-wrapper/agent-wrapper
health_check
```

## Notas

- ✅ **Update-safe**: Nada está en `/home/clawd/.npm-global/lib/node_modules/openclaw/`
- ✅ **Persistente**: Las memorias van a `/workspace/skills/brainx-v2/storage/`
- ✅ **Global**: Funciona con cualquier agente (Claude, Gemini, código propio)
- ⚠️  Requiere hacer `source` manualmente en cada sesión
