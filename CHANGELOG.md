# Changelog

All notable changes to BrainX v2 are documented in this file.

## [2.1.0] - 2026-02-10

### Added

**Metrics Tracking**
- Token usage tracking per session/agent
- Cost calculation (configurable per-token cost)
- Session duration tracking
- CSV export capability
- Automatic cleanup of old entries

**Distributed Scheduler**
- Agent-aware cron jobs
- Interval-based scheduling
- Task enable/disable toggling
- Crontab generation/export
- Task execution logging
- Webhook integration on completion

**Webhooks System**
- External notifications (Discord, Slack, custom)
- Event-based triggering (session_start, session_end, decision, error)
- HTTP methods support (POST, GET)
- Automatic retry and error handling
- Webhook history logs

**Audit Logging**
- Complete query trail
- Memory access logging (read/write/update/delete)
- Inter-agent message tracking
- Security audit reports
- Agent activity reports
- Compliance export (JSON)

**CLI Enhancements**
- New `metrics` command group
- New `schedule` command group
- New `webhook` command group
- New `audit` command group
- Help text for all new commands

**Multi-Agent Cluster**
- 7 agents registered: clawma, coder, main, reasoning, researcher, support, writer
- PostgreSQL backend integration
- Auto-load shell wrapper

## [2.0.0] - 2026-02-10

### Added

**Unified System**
- Consolidated four separate skills into one unified system
- Single entry point CLI (`brainx-v2`)
- Shared configuration file
- Unified documentation

**From memory-nucleo**
- Hot/Warm/Cold tiered storage
- RAG search and indexing
- Agent hooks (start, decision, action, learning, gotcha, end)
- Agent registry

**From brainx**
- Core functions (init, log, error, health)
- Relevance scoring
- Context building
- Memory injection pipeline

**From brainx-optimizer**
- Relevance filtering
- Token compression
- Tool batching
- Token estimation

**From second-brain**
- Categorical knowledge storage
- Knowledge search
- Markdown format

**New Features**
- Result caching with TTL
- Unified configuration
- Comprehensive documentation
- Architecture diagrams
- Demo and test scripts

### Changed
- Reorganized directory structure
- Standardized function naming
- Improved error handling
- Enhanced logging with levels

### Deprecated
- Old skill paths (symlinks provided for backward compatibility)

### Migration
- Symlinks created for backward compatibility:
  - `brainx` → `brainx-v2`
  - `brainx-optimizer` → `brainx-v2`
  - `memory-nucleo` → `brainx-v2`
  - `second-brain` → `brainx-v2`

## [1.0.0] - Previous Versions

### memory-nucleo v1.0.0
- Initial storage implementation
- RAG search
- Agent hooks

### brainx v1.0.0
- Core functions
- Context building
- Memory injection

### brainx-optimizer v1.0.0
- Filtering
- Compression
- Batching

### second-brain v1.0.0
- Knowledge storage
- Category management
