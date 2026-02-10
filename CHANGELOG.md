# Changelog

All notable changes to BrainX v2 are documented in this file.

## [2.0.0] - 2024-02-10

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
