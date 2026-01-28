#!/bin/bash

# CRE Workflow Test Runner
# Runs all test scenarios against the POR workflow using the CRE simulator

set -e

# Configuration - uses script's directory as project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
WORKFLOW_PATH="./por-workflow"
BASE_URL="https://por-api-server.onrender.com/api/reserves"
TARGET="staging-settings"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Run a single test case
run_test() {
    local test_name="$1"
    local url="$2"
    local expected_success="$3"  # "true" or "false"

    TOTAL=$((TOTAL + 1))

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Test ${TOTAL}: ${test_name}${NC}"
    echo -e "${BLUE}URL: ${url}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Build the HTTP payload
    local payload="{\"testCase\":\"${test_name}\",\"url\":\"${url}\"}"

    # Run the CRE simulator
    local output
    output=$(cre workflow simulate "$WORKFLOW_PATH" \
        --project-root "$PROJECT_ROOT" \
        --non-interactive \
        --trigger-index 0 \
        --http-payload "$payload" \
        --target "$TARGET" 2>&1) || true

    # Check if workflow succeeded
    if echo "$output" | grep -q '"success": true'; then
        if [ "$expected_success" = "true" ]; then
            echo -e "${GREEN}✓ PASSED${NC} - Workflow succeeded as expected"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC} - Workflow succeeded but was expected to fail"
            FAILED=$((FAILED + 1))
        fi
    else
        if [ "$expected_success" = "false" ]; then
            echo -e "${GREEN}✓ PASSED${NC} - Workflow failed as expected"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC} - Workflow failed but was expected to succeed"
            FAILED=$((FAILED + 1))
        fi
    fi

    # Show relevant output (user logs only)
    echo ""
    echo "$output" | grep -E "\[USER LOG\]|Workflow Simulation Result:" | head -20
}

# Print header
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           CRE POR Workflow Test Suite                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================================
# SIZE LIMIT TESTS
# ============================================================================
echo -e "\n${YELLOW}▶ SIZE LIMIT TESTS${NC}"

run_test "under_limit" "${BASE_URL}/?scenario=under_limit" "true"
run_test "at_limit" "${BASE_URL}/?scenario=at_limit" "true"
run_test "exceeds_limit" "${BASE_URL}/?scenario=exceeds_limit" "false"
run_test "way_over_limit" "${BASE_URL}/?scenario=way_over_limit" "false"

# ============================================================================
# TIMEOUT TESTS
# ============================================================================
echo -e "\n${YELLOW}▶ TIMEOUT TESTS${NC}"

run_test "under_connection_timeout" "${BASE_URL}/?scenario=under_connection_timeout" "true"
run_test "connection_timeout" "${BASE_URL}/?scenario=connection_timeout" "false"

# ============================================================================
# RESPONSE FORMAT TESTS
# ============================================================================
echo -e "\n${YELLOW}▶ RESPONSE FORMAT TESTS${NC}"

run_test "invalid_json" "${BASE_URL}/?scenario=invalid_json" "false"
run_test "empty_response" "${BASE_URL}/?scenario=empty_response" "false"
run_test "wrong_content_type" "${BASE_URL}/?scenario=wrong_content_type" "true"
run_test "partial_json" "${BASE_URL}/?scenario=partial_json" "false"
run_test "missing_fields" "${BASE_URL}/?scenario=missing_fields" "false"
run_test "invalid_types" "${BASE_URL}/?scenario=invalid_types" "false"
run_test "null_values" "${BASE_URL}/?scenario=null_values" "false"

# ============================================================================
# DATA VALIDITY TESTS
# ============================================================================
echo -e "\n${YELLOW}▶ DATA VALIDITY TESTS${NC}"

run_test "negative_values" "${BASE_URL}/?scenario=negative_values" "true"
run_test "underbacked" "${BASE_URL}/?scenario=underbacked" "true"

# ============================================================================
# CONNECTION TESTS
# ============================================================================
echo -e "\n${YELLOW}▶ CONNECTION TESTS${NC}"

run_test "connection_abort" "${BASE_URL}/?scenario=connection_abort" "false"

# ============================================================================
# HTTP ERROR TESTS
# ============================================================================
echo -e "\n${YELLOW}▶ HTTP ERROR TESTS${NC}"

run_test "error_400" "${BASE_URL}/?error=400" "false"
run_test "error_401" "${BASE_URL}/?error=401" "false"
run_test "error_403" "${BASE_URL}/?error=403" "false"
run_test "error_404" "${BASE_URL}/?error=404" "false"
run_test "error_429" "${BASE_URL}/?error=429" "false"
run_test "error_500" "${BASE_URL}/?error=500" "false"
run_test "error_502" "${BASE_URL}/?error=502" "false"
run_test "error_503" "${BASE_URL}/?error=503" "false"
run_test "error_504" "${BASE_URL}/?error=504" "false"

# ============================================================================
# SUMMARY
# ============================================================================
echo -e "\n${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                      TEST SUMMARY                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "Total:  ${TOTAL}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed.${NC}"
    exit 1
fi
