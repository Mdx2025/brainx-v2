# BrainX v2 Architecture

## System Overview

BrainX v2 is designed as a modular, library-based system where each component handles a specific concern while integrating seamlessly with others.

```
                              ┌─────────────────────┐
                              │      brainx-v2      │
                              │    (Main CLI)       │
                              └──────────┬──────────┘
                                         │
            ┌────────────────────────────┼────────────────────────────┐
            │                            │                            │
    ┌───────┴───────┐           ┌───────┴───────┐           ┌────────┴───────┐
    │   lib/core.sh │           │  lib/inject.sh│           │ lib/context.sh │
    │  (Initialize) │           │  (Pipeline)   │           │ (Build Ctx)    │
    └───────┬───────┘           └───────┬───────┘           └────────┬───────┘
            │                           │                            │
    ┌───────┴───────────────────────────┴────────────────────────────┴───────┐
    │                           Component Layer                               │
    ├────────────┬─────────────┬────────────┬────────────┬──────────────────┤
    │  storage   │    rag      │   hooks    │  scoring   │  second-brain    │
    │  .sh       │    .sh      │   .sh      │  .sh       │  .sh             │
    └────────────┴─────────────┴────────────┴────────────┴──────────────────┘
    ┌────────────┬─────────────┬────────────┬────────────┬──────────────────┐
    │  filter    │  compressor │  batcher   │  estimator │    caching       │
    │  .sh       │  .sh        │  .sh       │  .sh       │    .sh           │
    └────────────┴─────────────┴────────────┴────────────┴──────────────────┘
                                         │
                              ┌──────────┴──────────┐
                              │  config/brainx.conf │
                              │   (Configuration)   │
                              └─────────────────────┘
```

## Component Breakdown

### Core Layer (lib/core.sh)

Provides foundational functions:
- `brainx_init()` - Initialize system directories and state
- `brainx_log()` - Logging with levels (ERROR, WARN, INFO, DEBUG, SUCCESS)
- `brainx_error()` - Error handling
- `brainx_health()` - System health check
- `brainx_generate_id()` - Generate unique IDs
- `brainx_timestamp()` - Get current timestamp

### Storage Layer (lib/storage.sh)

Tiered memory storage with automatic tier management:

```
┌─────────────────────────────────────────────────┐
│                 Storage Tiers                    │
├─────────────┬─────────────┬─────────────────────┤
│    HOT      │    WARM     │       COLD          │
│  (Active)   │  (Recent)   │    (Archive)        │
│  < 100 items│  < 1000     │    Unlimited        │
│  Fast access│  Med access │    Slow access      │
└──────┬──────┴──────┬──────┴──────────┬──────────┘
       │             │                 │
       ▼             ▼                 ▼
   promote()    standard          archive()
```

Functions:
- `storage_add()` - Add entry with tier
- `storage_get()` - Retrieve by ID
- `storage_search()` - Search across tiers
- `storage_promote()` - Move to hot tier
- `storage_archive()` - Move to cold tier
- `storage_recall()` - Progressive recall

### RAG Layer (lib/rag.sh)

Retrieval-Augmented Generation search:

```
┌──────────────┐    ┌───────────────┐    ┌─────────────┐
│  Content     │───▶│   Indexer     │───▶│  RAG Index  │
│  (files,     │    │  (tokenize,   │    │  (.json)    │
│   memories)  │    │   score)      │    │             │
└──────────────┘    └───────────────┘    └──────┬──────┘
                                                │
┌──────────────┐    ┌───────────────┐           │
│   Query      │───▶│   Search      │◀──────────┘
│              │    │  (relevance)  │
└──────────────┘    └───────┬───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │   Results     │
                    │  (scored,     │
                    │   ranked)     │
                    └───────────────┘
```

### Hooks Layer (lib/hooks.sh)

Agent session and event tracking:

```
Session Start
     │
     ├──▶ decision
     ├──▶ action
     ├──▶ learning
     ├──▶ gotcha
     │
Session End
```

### Scoring Layer (lib/scoring.sh)

Relevance scoring with weighted factors:

```
Score = (Content × 0.6) + (Context × 0.3) + (Tags × 0.1)
        ─────────────────────────────────────────────────
                            100

Where:
- Content: Keyword matches in content
- Context: Keyword matches in context
- Tags: Keyword matches in tags
```

### Optimization Layer

**Filter (lib/filter.sh)**
- Filter results by score threshold
- Sort results by relevance

**Compressor (lib/compressor.sh)**
- Remove extra whitespace
- Truncate long content
- Preserve meaning

**Batcher (lib/batcher.sh)**
- Group tool calls
- Optimize API usage

**Estimator (lib/estimator.sh)**
- Estimate token count (~4 chars/token)

### Caching Layer (lib/caching.sh)

Result caching for performance:

```
Query ──▶ [Cache Check] ──▶ HIT ──▶ Return cached
                │
                └──▶ MISS ──▶ Execute ──▶ Cache ──▶ Return
```

### Context Layer (lib/context.sh)

Build context for LLM injection:

```
Query
  │
  ├──▶ Search memories
  ├──▶ Search second-brain
  ├──▶ Score results
  ├──▶ Filter by threshold
  ├──▶ Build context block
  │
  ▼
Context (formatted for LLM)
```

### Injection Pipeline (lib/inject.sh)

Full injection pipeline:

```
Query ──▶ Search ──▶ Score ──▶ Filter ──▶ Build ──▶ Compress ──▶ Format
                                          Context
```

### Second-Brain (lib/second-brain.sh)

Personal knowledge base:

```
knowledge/
├── commands/
│   ├── 12345.md
│   └── 12346.md
├── tips/
│   └── 12347.md
└── CORE/
    └── 12348.md
```

## Data Flow

### Memory Addition

```
User ──▶ add command ──▶ storage_add() ──▶ Create JSON ──▶ Save to tier
                              │
                              └──▶ rag_index_content() ──▶ RAG Index
```

### Memory Retrieval

```
User ──▶ search command ──▶ storage_search() ──▶ Search all tiers
                                   │
                                   └──▶ Return matches
```

### Injection Pipeline

```
User ──▶ inject command ──▶ inject_memories()
                                   │
                                   ├──▶ storage_search()
                                   ├──▶ filter_threshold()
                                   ├──▶ build_context()
                                   ├──▶ compress_tokens()
                                   └──▶ format_injection()
                                            │
                                            ▼
                                   Formatted context for LLM
```

## Integration Points

### For Agents

Agents can:
1. Start sessions with hooks
2. Record decisions, actions, learnings
3. Query memories via inject pipeline
4. End sessions

### For External Tools

External tools can:
1. Index content via RAG
2. Search memories
3. Add to second-brain
4. Query context

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Add memory | O(1) | Direct file write |
| Get by ID | O(1) | Direct file read |
| Search | O(n) | Scans all entries |
| RAG search | O(n) | Scans indexed content |
| Inject | O(n) | Combines search + process |

### Optimization Tips

1. **Use hot storage** for frequently accessed memories
2. **Archive old memories** to cold storage
3. **Enable caching** for repeated queries
4. **Adjust thresholds** for your use case

## File Formats

### Memory JSON

```json
{
  "id": "1234567890-abc123",
  "type": "decision",
  "content": "Memory content",
  "context": "Additional context",
  "tier": "warm",
  "timestamp": "2024-01-15 10:30:00",
  "access_count": 5
}
```

### RAG Index JSON

```json
{
  "id": "hash123",
  "filename": "file.md",
  "path": "/path/to/file.md",
  "content": "Indexed content",
  "indexed": "2024-01-15T10:30:00+00:00",
  "lines": 42
}
```

### Second-Brain Markdown

```markdown
---
id: 1234567890-abc123
category: commands
created: 2024-01-15 10:30:00
---

Knowledge content here
```
