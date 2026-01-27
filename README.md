# CRE Proof of Reserve Testing

A comprehensive testing suite for Chainlink Runtime Environment (CRE) Proof of Reserve workflows. This project contains both a mock API server and CRE workflows to test error handling, resilience, and edge cases.

## Project Structure

```
cre-por-testing/
├── por-api-server/       # Mock REST API server for testing
│   ├── server.js         # Express server with test scenarios
│   ├── scenarios.html    # Interactive browser UI
│   ├── TEST_CASES.md     # Complete test documentation
│   └── README.md         # API server documentation
│
└── cre/                  # CRE workflows (to be created)
    └── (your CRE workflow code)
```

## Overview

### por-api-server

A REST API server that simulates various proof of reserve scenarios for testing CRE workflows. Features:

- **25+ test scenarios** covering size limits, timeouts, HTTP errors, format issues, and data validity
- **Single endpoint** (`/api/reserves/`) with query parameters to trigger different behaviors
- **Interactive HTML UI** for easy testing and demonstration
- **CRE limit testing** - specifically designed to test against CRE's constraints:
  - 100 KB HTTP response size limit
  - 10 second connection timeout
  - 3 minute capability call timeout

### cre

Directory for your CRE workflow that will consume the API server to test proof of reserve scenarios.

## Quick Start

### 1. Start the API Server

```bash
cd por-api-server
bun install
bun start
```

The server runs on `http://localhost:3000`

### 2. Test with Browser UI

Open `por-api-server/scenarios.html` in your browser to access the interactive test interface with clickable links for all scenarios.

### 3. Create Your CRE Workflow

The `cre/` directory is ready for your Chainlink Runtime Environment workflow code that will test against the API server.

## Example CRE Workflow Usage

```typescript
import { http } from "@chainlink/cre-typescript-sdk/capabilities";

// Normal case - should succeed
const normal = await http.get("http://localhost:3000/api/reserves/");

// Test size limit - should fail (exceeds 100 KB)
try {
  const oversized = await http.get(
    "http://localhost:3000/api/reserves/?scenario=exceeds_limit"
  );
} catch (error) {
  console.error("Size limit error:", error);
}

// Test timeout - should fail (exceeds 10s connection timeout)
try {
  const timeout = await http.get(
    "http://localhost:3000/api/reserves/?scenario=connection_timeout"
  );
} catch (error) {
  console.error("Timeout error:", error);
}

// Test HTTP errors
try {
  const serverError = await http.get(
    "http://localhost:3000/api/reserves/?error=500"
  );
} catch (error) {
  console.error("Server error:", error);
}
```

## Test Scenarios

The API server provides comprehensive test scenarios:

### Size Limits
- Under limit (99 KB) - Should work
- At limit (100 KB) - Edge case
- Exceeds limit (150 KB) - Should fail in CRE
- Way over limit (500 KB) - Should fail in CRE

### Timeouts
- Connection timeout (11s) - Should fail in CRE
- Capability timeout (3.5min) - Should fail in CRE
- Custom delays - Configurable via `?delay=<ms>`

### HTTP Errors
- 400, 401, 403, 404, 429, 500, 502, 503, 504

### Response Format Issues
- Invalid JSON
- Empty response
- Wrong content-type
- Partial JSON
- Missing required fields
- Invalid data types
- Null values

### Data Validity
- Negative reserve values
- Under-backed reserves (ratio < 1.0)

### Connection Issues
- Connection abort mid-response

See [`por-api-server/TEST_CASES.md`](./por-api-server/TEST_CASES.md) for complete documentation.

## Documentation

- **[por-api-server/README.md](./por-api-server/README.md)** - API server setup and usage
- **[por-api-server/TEST_CASES.md](./por-api-server/TEST_CASES.md)** - Detailed test scenario documentation
- **[por-api-server/scenarios.html](./por-api-server/scenarios.html)** - Interactive browser UI

## Development Workflow

1. **Start the API server** in one terminal:
   ```bash
   cd por-api-server && bun start
   ```

2. **Develop your CRE workflow** in the `cre/` directory

3. **Test your workflow** against various scenarios using the API endpoints

4. **Use the browser UI** (`scenarios.html`) for manual testing and demonstration

## CRE Limits Reference

This testing suite is designed around CRE's documented limits:

| Limit | Value | Test Scenarios |
|-------|-------|----------------|
| HTTP Response Size | 100 KB | under_limit, at_limit, exceeds_limit, way_over_limit |
| HTTP Connection Timeout | 10 seconds | connection_timeout, under_connection_timeout |
| Capability Call Timeout | 3 minutes | capability_timeout, under_capability_timeout |
| HTTP Request Payload | 10 KB | (not tested server-side) |

## Contributing

When adding new test scenarios:

1. Add the scenario logic in `por-api-server/server.js`
2. Document it in `por-api-server/TEST_CASES.md`
3. Add it to `por-api-server/scenarios.html` for browser testing
4. Update this README if needed

## License

MIT
