# BrainX v2

> Unified Memory Intelligence System for OpenClaw Multi-Agent

## What is BrainX v2?

BrainX v2 is a **unified memory intelligence system** designed for distributed multi-agent environments. It provides:

- **Tiered Storage**: Hot/Warm/Cold memory tiers with automatic management
- **RAG Search**: Keyword-based semantic search with relevance scoring
- **Agent Hooks**: Session tracking, decisions, actions, learnings, gotchas
- **Metrics Tracking**: Token usage, cost, time per agent/session
- **Distributed Scheduler**: Agent-aware cron jobs
- **Webhooks**: External notifications (Discord, Slack, custom)
- **Audit Log**: Complete trail of queries, access, and inter-agent messages
- **Second-Brain**: Personal knowledge base with categories

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    BrainX V2 Core                        │
├─────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Storage  │ │   RAG     │ │  Hooks   │ │Metrics   │  │
│  │ Hot/Warm│ │  Search   │ │ Tracking │ │ Tracking │  │
│  │ Cold    │ │           │ │          │ │          │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
├─────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │Scheduler │ │ Webhooks │ │  Audit   │ │2nd-Brain │  │
│  │  Cron    │ │ Notifs   │ │   Log    │ │Knowledge │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
└─────────────────────────────────────────────────────────┘
         ▲                    ▲              ▲
         │                    │              │
    ┌────┴────┐          ┌────┴────┐   ┌─────┴────┐
    │ CLAWMA  │          │  CODER  │   │  MAIN    │
    └─────────┘          └─────────┘   └──────────┘
    ┌─────────┐          ┌─────────┐   ┌──────────┐
    │PROJECTS │          │SUPPORT  │   │ RESEARCH │
    └─────────┘          └─────────┘   └──────────┘
```

## Installation

Pre-installed at: `/home/clawd/.openclaw/workspace/skills/brainx-v2/`

Ensure it's executable:
```bash
chmod +x /home/clawd/.openclaw/workspace/skills/brainx-v2/brainx-v2
```

## Quick Start

```bash
# Source the wrapper (auto-loads in bashrc)
source /home/clawd/.openclaw/workspace/skills/brainx-v2/agent-wrapper.shellrc.sh

# Check system health
brainx-v2 health

# View statistics
brainx-v2 stats
```

## Commands Reference

### Memory Management

```bash
brainx-v2 add <type> <content> [context] [tier]    # Add memory
brainx-v2 get <id>                                  # Get by ID
brainx-v2 search <query>                            # Search all
brainx-v2 recall [context] [limit]                  # Progressive recall
```

### Storage Tiers

```bash
brainx-v2 hot|warm|cold <subcommand>                # Manage tier
# Subcommands: list, count, cleanup
```

### Agent Hooks

```bash
brainx-v2 hook start <agent> <context>             # Start session
brainx-v2 hook decision <action> <reason> [imp]     # Record decision
brainx-v2 hook action <desc> <result> [tags]        # Record action
brainx-v2 hook learning <pattern> <lesson> [src]    # Record learning
brainx-v2 hook gotcha <issue> <workaround> [sev]    # Record workaround
brainx-v2 hook end <summary>                        # End session
```

### RAG Search

```bash
brainx-v2 rag <query>                               # Semantic search
brainx-v2 rag index <path>                           # Index content
```

### Second-Brain

```bash
brainx-v2 sb add <category> <content>              # Add knowledge
brainx-v2 sb search <query>                          # Search knowledge
brainx-v2 sb list                                    # List categories
```

### Metrics & Tracking (NEW)

Track token usage, cost, and time per agent/session:

```bash
brainx-v2 metrics start <agent> <context>          # Start tracking session
brainx-v2 metrics tokens <id> <in> <out> <cost>     # Track token usage
brainx-v2 metrics end <id> <summary>                # End tracking session
brainx-v2 metrics report                            # Show metrics report
brainx-v2 metrics export [file.csv]                  # Export to CSV
brainx-v2 metrics cleanup [keep]                    # Cleanup old entries
```

**Example:**
```bash
# Track a coding session
SESSION_ID=$(brainx-v2 metrics start coder "Implementing API")
brainx-v2 metrics tokens $SESSION_ID 1500 500 0.02
# ... more work ...
brainx-v2 metrics end $SESSION_ID "API completed"
```

### Scheduled Tasks (NEW)

Distributed, agent-aware cron jobs:

```bash
brainx-v2 schedule add <name> <cron> <agent> <cmd>   # Add task
brainx-v2 schedule list                                # List tasks
brainx-v2 schedule run <id>                            # Run immediately
brainx-v2 schedule remove <id>                         # Remove task
brainx-v2 schedule toggle <id>                          # Enable/disable
brainx-v2 schedule sync                                 # Generate crontab
```

**Example:**
```bash
# Daily backup at 2 AM
brainx-v2 schedule add "backup" "0 2 * * *" clawma "brainx-v2 sb list"

# Hourly health check
brainx-v2 schedule add "health" "interval:3600" main "brainx-v2 health"
```

### Webhooks (NEW)

External notifications:

```bash
brainx-v2 webhook register <name> <url> <event>      # Register webhook
brainx-v2 webhook list                                 # List webhooks
brainx-v2 webhook trigger <id> <payload>               # Manual trigger
brainx-v2 webhook remove <id>                          # Remove webhook
brainx-v2 webhook test <id>                            # Test webhook
brainx-v2 webhook logs                                  # View logs
```

**Example:**
```bash
# Discord notification on session end
brainx-v2 webhook register "discord" "https://discord.com/api/webhooks/..." session_end

# Slack for errors
brainx-v2 webhook register "slack" "https://hooks.slack.com/..." error
```

### Audit Log (NEW)

Complete trail of system activity:

```bash
brainx-v2 audit query [agent] [type] [limit]         # Query logs
brainx-v2 audit activity <agent> [days]              # Activity report
brainx-v2 audit security                              # Security report
brainx-v2 audit stats                                  # Statistics
brainx-v2 audit cleanup [days]                         # Cleanup old entries
```

**Example:**
```bash
# See recent queries by clawma
brainx-v2 audit query clawma

# Activity report for last 7 days
brainx-v2 audit activity coder 7

# Security audit
brainx-v2 audit security
```

### Optimization Pipeline

```bash
brainx-v2 inject <query>          # Full injection pipeline
brainx-v2 filter <query>           # Filter by relevance
brainx-v2 compress <text>          # Compress text
brainx-v2 batch <tool_calls>       # Batch tools
brainx-v2 score <query> [id]       # Score relevance
```

### Utilities

```bash
brainx-v2 agents                   # List registered agents
brainx-v2 stats                     # Show statistics
brainx-v2 health                    # System health check
brainx-v2 help                      # Show help
```

## Agent Wrapper

For automatic workspace detection and agent context:

```bash
# Auto-detects workspace
source /home/clawd/.openclaw/workspace/skills/brainx-v2/agent-wrapper.shellrc.sh

# Commands available:
session_start "context"       # Start work session
session_decision "action" "reason" [importance]
session_action "desc" "result" [tags]
session_learning "pattern" "lesson" [source]
session_gotcha "issue" "workaround" [severity]
session_end "summary"

search_memory "query"          # Search memories
inject_context "query"         # Inject context

agent_send <agent> <msg>      # Send to another agent
agent_broadcast <msg>          # Broadcast to all

health_check                   # Check system health
show_status                    # Show wrapper status
```

## Multi-Agent Setup

8 agents registered in the cluster:

| Agent | Workspace | Status |
|-------|-----------|--------|
| clawma | workspace-clawma | ready |
| coder | workspace-coder | ready |
| main | workspace-main | ready |
| projects | workspace-projects | ready |
| reasoning | workspace-reasoning | ready |
| researcher | workspace-researcher | ready |
| support | workspace-support | ready |
| writer | workspace-writer | ready |

## PostgreSQL Integration

BrainX v2 can use PostgreSQL as backend:

```bash
# Connection string (configured)
postgresql://brainx:brainx@localhost:5432/brainx_v2

# Tables created:
# - brainx_sessions
# - brainx_decisions
# - brainx_actions
# - brainx_learnings
# - brainx_gotchas
# - brainx_messages
```

## Documentation

- **[SKILL.md](SKILL.md)** - Full skill documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[memory/](memory/)** - Daily notes and context

## Version History

### v2.0.0 (2026-02-10)
- ✅ Multi-agent support with 8 agents
- ✅ PostgreSQL backend integration
- ✅ **NEW**: Metrics tracking (tokens, cost, time)
- ✅ **NEW**: Distributed scheduler (cron jobs)
- **NEW**: Webhooks (Discord, Slack, custom)
- ✅ **NEW**: Audit logging (security, compliance)
- ✅ Auto-load wrapper for shell
- ✅ Second-Brain knowledge base

## License

MIT

---

**Repository**: https://github.com/Mdx2025/brainx-v2  
**Maintained by**: OpenClaw Multi-Agent System
