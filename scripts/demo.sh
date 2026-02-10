#!/bin/bash
# BrainX v2 Demo Script
# scripts/demo.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAINX_HOME="$(dirname "$SCRIPT_DIR")"
BRAINX_CLI="$BRAINX_HOME/brainx-v2"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}================================${NC}"
echo -e "${CYAN}   BrainX v2 Demo Script        ${NC}"
echo -e "${CYAN}================================${NC}"
echo ""

# 1. Help
echo -e "${YELLOW}1. Show Help${NC}"
$BRAINX_CLI help | head -20
echo "..."
echo ""

# 2. Add memories
echo -e "${YELLOW}2. Adding memories...${NC}"
id1=$($BRAINX_CLI add decision "Use caching for API responses" "Performance optimization" hot)
echo -e "${GREEN}Added decision: $id1${NC}"

id2=$($BRAINX_CLI add learning "Pattern: retry with backoff" "Network resilience" warm)
echo -e "${GREEN}Added learning: $id2${NC}"

id3=$($BRAINX_CLI add gotcha "API rate limiting" "Use exponential backoff" warm)
echo -e "${GREEN}Added gotcha: $id3${NC}"
echo ""

# 3. Search
echo -e "${YELLOW}3. Searching memories...${NC}"
$BRAINX_CLI search "API"
echo ""

# 4. Second-Brain
echo -e "${YELLOW}4. Adding to Second-Brain...${NC}"
sb_id=$($BRAINX_CLI sb add commands "grep -r 'pattern' ." "Search recursively")
echo -e "${GREEN}Added to second-brain: $sb_id${NC}"

echo ""
echo -e "${YELLOW}5. Listing Second-Brain categories...${NC}"
$BRAINX_CLI sb list
echo ""

# 5. Agent hooks
echo -e "${YELLOW}6. Demonstrating agent hooks...${NC}"
session_id=$($BRAINX_CLI hook start demo "Demo session")
echo -e "${GREEN}Started session: $session_id${NC}"

$BRAINX_CLI hook decision "Using demo mode" "To show features" 5
$BRAINX_CLI hook learning "Hook pattern" "Always end sessions" "demo"
$BRAINX_CLI hook end "Demo completed successfully"
echo ""

# 6. Health check
echo -e "${YELLOW}7. System Health Check${NC}"
$BRAINX_CLI health
echo ""

# 7. Statistics
echo -e "${YELLOW}8. Statistics${NC}"
$BRAINX_CLI stats
echo ""

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}   Demo Complete!               ${NC}"
echo -e "${GREEN}================================${NC}"
