#!/bin/bash
# BrainX v2 Test Suite
# scripts/test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAINX_HOME="$(dirname "$SCRIPT_DIR")"
BRAINX_CLI="$BRAINX_HOME/brainx-v2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
PASSED=0
FAILED=0

# Test function
test_case() {
    local name="$1"
    local command="$2"
    local expected="${3:-}"
    
    echo -n "Testing: $name... "
    
    if output=$(eval "$command" 2>&1); then
        if [[ -z "$expected" ]] || echo "$output" | grep -q "$expected"; then
            echo -e "${GREEN}PASSED${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAILED${NC} (expected: $expected)"
            echo "  Output: $output"
            ((FAILED++))
            return 1
        fi
    else
        echo -e "${RED}FAILED${NC} (command failed)"
        echo "  Output: $output"
        ((FAILED++))
        return 1
    fi
}

echo "================================"
echo "   BrainX v2 Test Suite"
echo "================================"
echo ""

# Test 1: CLI exists and is executable
test_case "CLI executable" "test -x $BRAINX_CLI"

# Test 2: Help command
test_case "Help command" "$BRAINX_CLI help" "USAGE"

# Test 3: Add memory
test_case "Add memory" "$BRAINX_CLI add test 'Test content' 'Test context' warm"

# Test 4: Search memories
test_case "Search memories" "$BRAINX_CLI search test" ""

# Test 5: Second-brain add
test_case "Second-brain add" "$BRAINX_CLI sb add test-category 'Test knowledge'"

# Test 6: Second-brain list
test_case "Second-brain list" "$BRAINX_CLI sb list" "Second-Brain"

# Test 7: Hook start
test_case "Hook start" "$BRAINX_CLI hook start test-agent 'Test session'"

# Test 8: Hook decision
test_case "Hook decision" "$BRAINX_CLI hook decision 'Test action' 'Test reason' 5"

# Test 9: Hook end
test_case "Hook end" "$BRAINX_CLI hook end 'Test completed'"

# Test 10: Health check
test_case "Health check" "$BRAINX_CLI health" "System health"

# Test 11: Stats
test_case "Stats" "$BRAINX_CLI stats" "Statistics"

# Test 12: Agents list
test_case "Agents list" "$BRAINX_CLI agents" "Agents"

# Test 13: Tier list
test_case "Tier list (hot)" "$BRAINX_CLI hot list" ""

# Test 14: RAG search
test_case "RAG search" "$BRAINX_CLI rag test" ""

# Test 15: Libraries exist
for lib in core storage rag hooks registry scoring filter compressor batcher estimator caching context inject second-brain; do
    test_case "Library: $lib.sh" "test -f $BRAINX_HOME/lib/$lib.sh"
done

# Test 16: Configuration exists
test_case "Config exists" "test -f $BRAINX_HOME/config/brainx.conf"

# Test 17: Documentation exists
test_case "SKILL.md exists" "test -f $BRAINX_HOME/SKILL.md"
test_case "README.md exists" "test -f $BRAINX_HOME/README.md"
test_case "ARCHITECTURE.md exists" "test -f $BRAINX_HOME/ARCHITECTURE.md"

echo ""
echo "================================"
echo "   Test Results"
echo "================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
