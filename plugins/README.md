# BrainX V2 Plugins

Plugins para integrar BrainX V2 con diferentes plataformas.

## OpenClaw Plugin

**Ubicación:** `plugins/openclaw/`

Integración automática con OpenClaw Gateway.

### Instalación

El plugin se instala automáticamente como symlink:

```bash
ln -s /path/to/brainx-v2/plugins/openclaw ~/.openclaw/extensions/memory-inyection
```

### Funcionalidades

- **Auto-detección de patrones**: emails, URLs, GitHub repos, commits, errores
- **Integración con BrainX V2**: storage hot/warm/cold
- **RAG search**: búsqueda semántica sobre el índice
- **Pattern matching configurable**

### Configuración

En `~/.openclaw/config.yaml`:

```yaml
plugins:
  entries:
    memory-inyection:
      enabled: true
      storage: brainx-v2
      patterns:
        email: true
        githubUrl: true
        commitSha: true
        errorStack: true
        filePaths: true
        urls: true
        finance: true
        dates: true
        secrets: true  # Detecta patrones de API keys (no las guarda)
```

### Uso

```bash
# El plugin se carga automáticamente con OpenClaw
openclaw gateway start

# Verificar estado
openclaw plugins list | grep memory
```

### Desarrollo

```bash
cd plugins/openclaw
npm install
npx tsc index.ts --outDir . --esModuleInterop --module commonjs
```

---

## Futuros Plugins

- **VS Code**: Integración con editor
- **CLI standalone**: Uso sin OpenClaw
- **API REST**: HTTP endpoint para integraciones
