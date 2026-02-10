# BrainX v2

> Unified Memory Intelligence System for OpenClaw

## What is BrainX v2?

BrainX v2 is a unified memory intelligence system that combines:
- **Storage**: Hot/Warm/Cold tiered memory storage
- **RAG**: Retrieval-Augmented Generation search
- **Hooks**: Agent session tracking
- **Optimization**: Token compression and batching
- **Second-Brain**: Personal knowledge base

## Installation

The skill is pre-installed at:
```
/home/clawd/.openclaw/workspace/skills/brainx-v2/
```

Ensure it's executable:
```bash
chmod +x /home/clawd/.openclaw/workspace/skills/brainx-v2/brainx-v2
```

## Quick Examples

```bash
# Add a memory
brainx-v2 add decision "Cache API responses" "Performance" hot

# Search memories
brainx-v2 search "API"

# Add knowledge
brainx-v2 sb add tips "Always check return values"

# Check system health
brainx-v2 health

# Get help
brainx-v2 help
```

## Documentation

- **[SKILL.md](SKILL.md)** - Full documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

## License

MIT
