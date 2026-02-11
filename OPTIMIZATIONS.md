# BrainX V2 - Optimizaciones de Costos

## Resumen de Optimizaciones Agregadas

Esta actualización agrega 4 nuevas optimizaciones de costos a BrainX V2:

### 1. **Prompt Compression Semántico** (`lib/compressor.sh`)
- Compresión basada en extracción de oraciones con mayor densidad de keywords
- Mantiene facts, números y relaciones causales
- Aplica solo cuando el contexto excede `COMPRESS_THRESHOLD`

**Config:**
```bash
SEMANTIC_COMPRESS=true           # Habilitar compresión semántica
COMPRESS_THRESHOLD=5000          # Umbral para activar compresión
COMPRESS_RATIO=0.4               # Ratio objetivo de compresión
```

### 2. **Response Caching por Query** (`lib/caching.sh`)
- Cachea respuestas LLM para queries idénticas
- Fuzzy matching semántico para queries similares
- TTL configurable para invalidación

**Config:**
```bash
RESPONSE_CACHE_ENABLED=true      # Cache de respuestas
SEMANTIC_CACHE=true              # Matching semántico
CACHE_TTL=3600                   # TTL en segundos
SIMILARITY_THRESHOLD=0.85        # Umbral de similitud
```

### 3. **Local Model Compression** (`lib/local_compressor.sh`)
- Usa `llama3.2-32k:latest` local (Ollama) para pre-procesar contexto
- Reduce tokens antes de llamar APIs costosas
- Funciones: compresión, summarization, pruning contextual

**Config:**
```bash
LOCAL_COMPRESS_ENABLED=true      # Habilitar compresión local
LOCAL_MODEL=llama3.2-32k:latest  # Modelo Ollama
LOCAL_MAX_TOKENS=2000            # Max tokens output
OLLAMA_HOST=http://localhost:11434
```

**Comandos:**
```bash
brainx-v2 local-compress "texto largo..."
brainx-v2 local-health           # Verificar Ollama
```

### 4. **Context Summarization Progresiva** (`lib/summarizer.sh`)
- Resume mensajes antiguos automáticamente
- Mantiene últimos N mensajes sin resumir
- Reduce historial que excede `MAX_HISTORY_TOKENS`

**Config:**
```bash
SUMMARIZER_ENABLED=true          # Habilitar summarization
SUMMARIZE_AFTER_N=10             # Resumir después de N mensajes
SUMMARY_MAX_TOKENS=300           # Max tokens por resumen
KEEP_MESSAGES_AFTER_SUMMARY=5    # Mensajes recientes a preservar
```

**Comandos:**
```bash
brainx-v2 summarize session.json
```

### 5. **Semantic Deduplication** (`lib/dedup.sh`)
- Elimina contenido semánticamente duplicado
- Múltiples métodos: hash, n-gram, keyword, hybrid
- Reduce contexto redundante antes de enviar a LLM

**Config:**
```bash
DEDUP_ENABLED=true               # Habilitar deduplicación
DEDUP_METHOD=hybrid              # hash|ngram|semantic|hybrid
SIMILARITY_THRESHOLD=0.85        # Umbral de similitud
MIN_CONTENT_LENGTH=50            # Longitud mínima a verificar
```

**Comandos:**
```bash
brainx-v2 dedup items.json
```

---

## Pipeline de Inyección Actualizado

El flujo ahora incluye todas las optimizaciones:

```
Query → [Response Cache?] → Search Memories → [Semantic Dedup] → 
Filter → Build Context → [Local Prune] → [Compress] → 
[Semantic Compress] → [Progressive Summarize] → Format → LLM
```

---

## Estimación de Ahorros

| Optimización | Reducción Estimada |
|--------------|-------------------|
| Response Caching | 20-40% (hits frecuentes) |
| Semantic Dedup | 10-25% (contexto redundante) |
| Local Compression | 30-50% (pre-proceso) |
| Progressive Summarization | 40-60% (historial largo) |
| **Total** | **50-70%** en escenarios óptimos |

---

## Instalación

1. **Ollama** (para local compression):
```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.2-32k:latest
```

2. **Dependencias**:
```bash
sudo apt-get install jq bc  # Si no están instalados
```

3. **Verificar**:
```bash
brainx-v2 health
brainx-v2 local-health
```

---

## Debugging

Ver logs de optimizaciones:
```bash
VERBOSE=true brainx-v2 inject "tu query"
```

Ver métricas de compresión:
```bash
brainx-v2 compress "texto de prueba"
brainx-v2 dedup items.json
brainx-v2 summarize session.json
```
