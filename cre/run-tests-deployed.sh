#!/bin/bash

# CRE Deployed Workflow Test Runner
# Runs all test scenarios against a DEPLOYED POR workflow via HTTP trigger
#
# Rate Limit: CRE enforces a rate limit of 1 trigger per 30 seconds (burst: 3)
# This script automatically handles the rate limiting with delays between tests.
#
# Prerequisites:
#   1. Copy .env.example to .env and configure:
#      - PRIVATE_KEY: Your EVM private key (must be authorized in workflow)
#      - GATEWAY_URL: CRE gateway URL
#      - WORKFLOW_ID: Your deployed workflow ID
#   2. Install dependencies: cd cre-sdk-typescript/packages/cre-http-trigger && bun install
#
# Usage:
#   ./run-tests-deployed.sh              # Run all tests (with rate limiting)
#   ./run-tests-deployed.sh under_limit  # Run single test (no delay)

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRIGGER_DIR="$SCRIPT_DIR/cre-sdk-typescript/packages/cre-http-trigger"
ENV_FILE="$SCRIPT_DIR/.env"
BASE_URL="https://por-api-server.onrender.com/api/reserves"
TRIGGER_PORT=2000
TRIGGER_URL="http://localhost:$TRIGGER_PORT"

# Rate limiting configuration (CRE quota)
RATE_LIMIT_BURST=3          # Initial burst allowed
RATE_LIMIT_INTERVAL=30      # Seconds between requests after burst

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
TOTAL=0
BURST_REMAINING=$RATE_LIMIT_BURST

# Cleanup function
cleanup() {
    if [ -n "$TRIGGER_PID" ]; then
        echo -e "\n${YELLOW}Stopping HTTP trigger server...${NC}"
        kill $TRIGGER_PID 2>/dev/null || true
        wait $TRIGGER_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"

    # Check .env file
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${RED}Error: .env file not found${NC}"
        echo -e "Copy .env.example to .env and configure your settings:"
        echo -e "  cp .env.example .env"
        exit 1
    fi

    # Load environment variables
    source "$ENV_FILE"

    # Validate required variables
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${RED}Error: PRIVATE_KEY not set in .env${NC}"
        exit 1
    fi

    if [ -z "$GATEWAY_URL" ]; then
        echo -e "${RED}Error: GATEWAY_URL not set in .env${NC}"
        exit 1
    fi

    if [ -z "$WORKFLOW_ID" ]; then
        echo -e "${RED}Error: WORKFLOW_ID not set in .env${NC}"
        exit 1
    fi

    # Check trigger tool
    if [ ! -d "$TRIGGER_DIR" ]; then
        echo -e "${RED}Error: cre-http-trigger not found${NC}"
        echo -e "Initialize the submodule:"
        echo -e "  git submodule update --init --recursive"
        exit 1
    fi

    # Check if bun is installed
    if ! command -v bun &> /dev/null; then
        echo -e "${RED}Error: bun is not installed${NC}"
        echo -e "Install bun: https://bun.sh"
        exit 1
    fi

    echo -e "${GREEN}Prerequisites OK${NC}"
    echo -e "  Gateway: $GATEWAY_URL"
    echo -e "  Workflow ID: ${WORKFLOW_ID:0:16}..."
}

# Start the HTTP trigger server
start_trigger_server() {
    echo -e "\n${BLUE}Starting HTTP trigger server...${NC}"

    # Check if already running
    if curl -s "$TRIGGER_URL/health" > /dev/null 2>&1; then
        echo -e "${YELLOW}Trigger server already running on port $TRIGGER_PORT${NC}"
        return
    fi

    # Install dependencies if needed
    if [ ! -d "$TRIGGER_DIR/node_modules" ]; then
        echo -e "${YELLOW}Installing trigger server dependencies...${NC}"
        (cd "$TRIGGER_DIR" && bun install)
    fi

    # Create .env for trigger server
    cat > "$TRIGGER_DIR/.env" << EOF
PRIVATE_KEY=$PRIVATE_KEY
GATEWAY_URL=$GATEWAY_URL
EOF

    # Start server in background
    (cd "$TRIGGER_DIR" && bun start) &
    TRIGGER_PID=$!

    # Wait for server to be ready
    echo -e "Waiting for server to start..."
    for i in {1..30}; do
        if curl -s "$TRIGGER_URL/health" > /dev/null 2>&1; then
            echo -e "${GREEN}Trigger server ready at $TRIGGER_URL${NC}"
            return
        fi
        sleep 1
    done

    echo -e "${RED}Error: Trigger server failed to start${NC}"
    exit 1
}

# Wait for rate limit with countdown
wait_for_rate_limit() {
    if [ "$BURST_REMAINING" -gt 0 ]; then
        BURST_REMAINING=$((BURST_REMAINING - 1))
        return
    fi

    echo -e "\n${YELLOW}⏳ Rate limit: waiting ${RATE_LIMIT_INTERVAL}s before next trigger...${NC}"
    for ((i=RATE_LIMIT_INTERVAL; i>0; i--)); do
        printf "\r${CYAN}   Next trigger in %2d seconds...${NC}" "$i"
        sleep 1
    done
    printf "\r${GREEN}   Ready to trigger!              ${NC}\n"
}

# Run a single test case
run_test() {
    local test_name="$1"
    local url="$2"
    local expected_success="$3"  # "true" or "false"
    local skip_rate_limit="$4"   # "true" to skip rate limit wait

    TOTAL=$((TOTAL + 1))

    # Apply rate limiting (unless skipped for single test)
    if [ "$skip_rate_limit" != "true" ]; then
        wait_for_rate_limit
    fi

    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Test ${TOTAL}: ${test_name}${NC}"
    echo -e "${CYAN}URL: ${url}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Build the payload
    local payload="{\"testCase\":\"${test_name}\",\"url\":\"${url}\"}"

    # Trigger the workflow
    local response
    response=$(curl -s -X POST "$TRIGGER_URL/trigger?workflowID=$WORKFLOW_ID" \
        -H "Content-Type: application/json" \
        -d "{\"input\": $payload}" 2>&1)

    echo -e "\n${CYAN}Response:${NC}"
    echo "$response" | head -20

    # Check response for errors
    if echo "$response" | grep -q '"error"'; then
        echo -e "${RED}✗ TRIGGER ERROR${NC}"
        FAILED=$((FAILED + 1))
    elif echo "$response" | grep -q '"workflow_execution_id"'; then
        echo -e "${GREEN}✓ TRIGGERED${NC} - Workflow execution started"
        echo -e "${CYAN}Check execution status in CRE UI: https://cre.chain.link/workflows${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${YELLOW}? UNKNOWN RESPONSE${NC}"
        FAILED=$((FAILED + 1))
    fi
}

# Print header
print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║       CRE POR Workflow - Deployed Tests                      ║"
    echo "║       (Triggers real workflow executions)                    ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Rate Limit: Burst 3, then 1 per 30s                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Calculate estimated time
calculate_eta() {
    local num_tests=$1
    local burst=$RATE_LIMIT_BURST
    local interval=$RATE_LIMIT_INTERVAL

    if [ "$num_tests" -le "$burst" ]; then
        echo "~1 minute"
    else
        local after_burst=$((num_tests - burst))
        local total_seconds=$((after_burst * interval))
        local minutes=$((total_seconds / 60))
        local seconds=$((total_seconds % 60))
        echo "~${minutes}m ${seconds}s"
    fi
}

# Run all tests
run_all_tests() {
    local total_tests=25
    local eta=$(calculate_eta $total_tests)

    echo -e "${CYAN}Running ${total_tests} tests. Estimated time: ${eta}${NC}"
    echo -e "${CYAN}(First ${RATE_LIMIT_BURST} tests run immediately, then ${RATE_LIMIT_INTERVAL}s delay between each)${NC}"

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
}

# Print summary
print_summary() {
    echo -e "\n${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      TEST SUMMARY                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "Total:     ${TOTAL}"
    echo -e "Triggered: ${GREEN}${PASSED}${NC}"
    echo -e "Failed:    ${RED}${FAILED}${NC}"

    echo -e "\n${CYAN}View execution results at: https://cre.chain.link/workflows${NC}"
}

# Main
main() {
    print_header
    check_prerequisites
    start_trigger_server

    if [ -n "$1" ]; then
        # Run single test (skip rate limit)
        echo -e "\n${YELLOW}Running single test: $1${NC}"
        run_test "$1" "${BASE_URL}/?scenario=$1" "unknown" "true"
    else
        # Run all tests (with rate limiting)
        run_all_tests
    fi

    print_summary
}

main "$@"
