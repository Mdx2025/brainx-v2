# MEMORY.md - Long-term Memory

## Sistema de Memoria Multi-Agente con BrainX V2

### Arquitectura

- **Backend**: BrainX V2 Centralizado
- **Wrapper**: Instalado en cada workspace
- **Conexión**: PostgreSQL / SQLite fallback

### Comandos del Wrapper

```bash
source /path/to/brainx-wrapper/agent-wrapper

session_start "contexto de trabajo"
session_decision "acción" "razón" [importancia]
session_action "descripción" "resultado" [tags]
session_learning "patrón" "lección" [fuente]
session_gotcha "problema" "solución" [severidad]
session_end "resumen"
```

### Tips de Uso

1. **Siempre hacer session_start/end** para mantener trazabilidad
2. **Usar tags** en actions para facilitar búsquedas
3. **Registrar gotchas** inmediatamente cuando los encontrás
4. **Antes de delegar** a otro agent, usar `search_memory`

### Patrones Importantes

Ver ARCHITECTURE.md en brainx-wrapper/ para documentación completa.
