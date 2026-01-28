# CRE Proof of Reserve Testing

Testing suite for Chainlink Runtime Environment (CRE) Proof of Reserve workflows. Includes a mock API server and test runners for both simulation and deployed workflows.

## Quick Start

```bash
# Clone with submodules
git clone --recursive <repo-url>
cd cre-por-testing

# Run tests in simulation
cd cre
./run-tests-simulation.sh
```

## Project Structure

| Directory | Description |
|-----------|-------------|
| `por-api-server/` | Mock API server with test scenarios ([docs](./por-api-server/README.md)) |
| `cre/por-workflow/` | CRE workflow implementation |
| `cre/run-tests-simulation.sh` | Test runner for simulation mode |
| `cre/run-tests-deployed.sh` | Test runner for deployed workflows |

## Running Tests

### Simulation Mode

Tests the workflow locally using the CRE simulator. No deployment required.

```bash
cd cre

./run-tests-simulation.sh                # Run all tests
./run-tests-simulation.sh under_limit    # Run single test
./run-tests-simulation.sh --list         # List available tests
```

### Deployed Mode

Tests against a deployed workflow on CRE. Requires configuration.

```bash
cd cre

# First time setup
git submodule update --init --recursive
cd cre-sdk-typescript/packages/cre-http-trigger && bun install && cd ../../..
cp .env.example .env
# Edit .env with: PRIVATE_KEY, GATEWAY_URL, WORKFLOW_ID

# Run tests
./run-tests-deployed.sh                  # Run all (rate limited: ~11 min)
./run-tests-deployed.sh under_limit      # Run single test
```

**Rate Limit:** CRE allows burst of 3, then 1 trigger per 30 seconds.

## Test Cases

| Category | Tests | Description |
|----------|-------|-------------|
| **Size Limits** | `under_limit`, `at_limit`, `exceeds_limit`, `way_over_limit` | Tests CRE's 100KB response limit |
| **Timeouts** | `under_connection_timeout`, `connection_timeout` | Tests CRE's 10s connection timeout |
| **Response Format** | `invalid_json`, `empty_response`, `wrong_content_type`, `partial_json`, `missing_fields`, `invalid_types`, `null_values` | Malformed API responses |
| **Data Validity** | `negative_values`, `underbacked` | Invalid reserve data |
| **Connection** | `connection_abort` | Connection drops mid-response |
| **HTTP Errors** | `error_400`, `error_401`, `error_403`, `error_404`, `error_429`, `error_500`, `error_502`, `error_503`, `error_504` | Standard HTTP error codes |

See [TEST_CASES.md](./por-api-server/TEST_CASES.md) for detailed documentation.

## CRE Limits

| Limit | Value |
|-------|-------|
| HTTP Response Size | 100 KB |
| HTTP Connection Timeout | 10 seconds |
| HTTP Trigger Rate | 1 per 30s (burst: 3) |

## Links

- [API Server Documentation](./por-api-server/README.md)
- [Test Cases Documentation](./por-api-server/TEST_CASES.md)
- [CRE Documentation](https://docs.chain.link/cre)
