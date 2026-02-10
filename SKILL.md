# BrainX v2 - Unified Memory Intelligence System

> A unified memory intelligence system integrating storage, RAG, hooks, scoring, optimization, and second-brain capabilities.

## ⚠️ Deprecation Notice

**The standalone `second-brain` skill has been deprecated.** All Second-Brain functionality is now integrated into BrainX v2:

```bash
# Old way (deprecated):
second-brain add WORK "note"

# New way (use brainx-v2):
brainx-v2 sb add WORK "note"
```

All existing second-brain entries are automatically accessible via `brainx-v2 sb search`.

## Overview

BrainX v2 consolidates four previously separate skills into a single, powerful memory intelligence system:

```
┌────────────────────────────────────────────────────────────────────┐
│                         BrainX v2                                   │
├────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐ │
│  │   Storage    │  │     RAG      │  │      Optimization        │ │
│  │  Hot/Warm/   │  │   Search &   │  │  Filter + Compress +     │ │
│  │    Cold      │  │    Index     │  │       Batch              │ │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬──────────────┘ │
│         │                 │                       │                │
│  ┌──────┴─────────────────┴───────────────────────┴──────────────┐ │
│  │                     Injection Pipeline                         │ │
│  │           Query → Search → Score → Filter → Context           │ │
│  └──────────────────────────┬────────────────────────────────────┘ │
│                             │                                      │
│  ┌──────────────┐  ┌───────┴────────┐  ┌──────────────────────┐  │
│  │    Hooks     │  │  Second-Brain  │  │      Registry        │  │
│  │  Decision/   │  │   Knowledge    │  │    Agent Mgmt        │  │
│  │   Action     │  │     Base       │  │                      │  │
│  └──────────────┘  └────────────────┘  └──────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

## Features

### Memory Management
- **Tiered Storage**: Hot, Warm, and Cold storage tiers with automatic promotion/archival
- **Progressive Recall**: Intelligent memory retrieval based on relevance and recency
- **Access Tracking**: Track memory usage for intelligent tier management

### RAG Search
- **Semantic Search**: Keyword-based search with relevance scoring
- **File Indexing**: Index files and directories for searchable content
- **Metadata Tracking**: Track indexed documents and search history

### Agent Hooks
- **Session Management**: Track agent sessions with start/end hooks
- **Decision Logging**: Record decisions with reasoning and importance
- **Action Tracking**: Log actions with results and tags
- **Learning Capture**: Capture patterns and lessons learned
- **Gotcha Recording**: Document workarounds and edge cases

### Optimization Pipeline
- **Token Compression**: Reduce token usage while preserving meaning
- **Tool Batching**: Batch parallel tool calls for efficiency
- **Relevance Filtering**: Filter results by score threshold
- **Result Caching**: Cache search results for performance

### Second-Brain
- **Categorical Knowledge**: Organize knowledge by category
- **Quick Search**: Search across all knowledge entries
- **Markdown Storage**: Human-readable markdown format

## Quick Start

```bash
# Add a memory
brainx-v2 add decision "Using cache for performance" "API optimization" hot

# Search memories
brainx-v2 search "performance optimization"

# Add to second-brain
brainx-v2 sb add commands "grep -r pattern" "Search recursively"

# Start an agent session
brainx-v2 hook start claude "Working on project X"

# Full injection pipeline
brainx-v2 inject "How do I configure nginx?"

# System health check
brainx-v2 health
```

## Command Reference

### Memory Management

| Command | Description |
|---------|-------------|
| `add <type> <content> [context] [tier]` | Add memory to storage |
| `get <id>` | Retrieve memory by ID |
| `search <query>` | Search all memories |
| `recall [context] [limit]` | Progressive recall |

### Storage Tiers

| Command | Description |
|---------|-------------|
| `hot list` | List hot storage entries |
| `warm count` | Count warm storage entries |
| `cold cleanup` | Clean up cold storage |

### Agent Hooks

| Command | Description |
|---------|-------------|
| `hook start <agent> <context>` | Start session |
| `hook decision <action> <reason> [importance]` | Record decision |
| `hook action <desc> <result> [tags]` | Record action |
| `hook learning <pattern> <lesson> [source]` | Record learning |
| `hook gotcha <issue> <workaround> [severity]` | Record gotcha |
| `hook end <summary>` | End session |

### RAG Search

| Command | Description |
|---------|-------------|
| `rag <query>` | Semantic search |
| `rag index <path>` | Index file or directory |
| `rag stats` | Show RAG statistics |

### Second-Brain

| Command | Description |
|---------|-------------|
| `sb add <category> <content>` | Add entry |
| `sb search <query>` | Search knowledge |
| `sb list` | List categories |

### Optimization

| Command | Description |
|---------|-------------|
| `inject <query>` | Full injection pipeline |
| `filter <query>` | Filter by relevance |
| `compress <text>` | Compress text |
| `batch <tools>` | Batch tool calls |
| `score <query> [id]` | Score relevance |

### Utilities

| Command | Description |
|---------|-------------|
| `agents` | List registered agents |
| `stats` | Show statistics |
| `health` | System health check |
| `help` | Show help |

## Configuration

Edit `config/brainx.conf`:

```bash
# Storage Tiers
STORAGE_HOT_DIR="$BRAINX_HOME/storage/hot"
STORAGE_WARM_DIR="$BRAINX_HOME/storage/warm"
STORAGE_COLD_DIR="$BRAINX_HOME/storage/cold"

# RAG Configuration
RAG_INDEX_DIR="$BRAINX_HOME/rag-index"
RAG_THRESHOLD=0.7

# Scoring
SCORE_THRESHOLD=70
SCORE_WEIGHT_CONTENT=0.6
SCORE_WEIGHT_CONTEXT=0.3
SCORE_WEIGHT_TAGS=0.1

# Optimization
COMPRESS_ENABLED=true
COMPRESS_THRESHOLD=500
BATCH_ENABLED=true
BATCH_MIN_TOOLS=2
BATCH_MAX_TOOLS=10

# Caching
CACHE_ENABLED=true
CACHE_TTL=3600

# Verbose
VERBOSE=false
```

## Integration Guide

### For Agents

```bash
# At session start
brainx-v2 hook start "my-agent" "Task description"

# During work - record decisions
brainx-v2 hook decision "Using approach X" "Because of reason Y" 8

# Record learnings
brainx-v2 hook learning "Pattern: X" "Lesson: Always do Y"

# At session end
brainx-v2 hook end "Completed task successfully"
```

### For Context Injection

```bash
# Get relevant context for a query
context=$(brainx-v2 inject "my query")
```

### For Knowledge Management

```bash
# Store important knowledge
brainx-v2 sb add "api" "Always use version 2 of the API"

# Search when needed
brainx-v2 sb search "API version"
```

## Troubleshooting

### Common Issues

**Issue: Memory not found**
- Check if the memory ID is correct
- Verify the storage tier

**Issue: RAG search returns no results**
- Index content first with `brainx-v2 rag index <path>`
- Lower the RAG_THRESHOLD in config

**Issue: Compression too aggressive**
- Increase COMPRESS_THRESHOLD in config
- Set COMPRESS_ENABLED=false to disable

### Debug Mode

Enable verbose logging:
```bash
VERBOSE=true brainx-v2 search "query"
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed system design.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

MIT License - see [LICENSE](LICENSE)
