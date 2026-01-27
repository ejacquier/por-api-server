# Proof of Reserve API Server

A REST API server for testing Proof of Reserve workflows with Chainlink Runtime Environment (CRE). This server simulates various API behaviors, errors, and edge cases to thoroughly test CRE workflow error handling and resilience.

## Features

- Single endpoint with configurable test scenarios
- Tests CRE limits: 100 KB response size, 10s connection timeout, 3min capability timeout
- Simulates HTTP errors (400, 401, 403, 404, 429, 500, 502, 503, 504)
- Tests response format issues (invalid JSON, empty responses, wrong content types)
- Configurable delays and timeouts
- Data validity scenarios (negative values, under-backed reserves)
- Connection issues (aborted connections, partial responses)

## Setup

Install dependencies:

```bash
bun install
```

## Running the Server

Start the server:

```bash
bun start
```

For development with auto-reload:

```bash
bun run dev
```

The server will run on `http://localhost:3000` by default. You can change the port by setting the `PORT` environment variable:

```bash
PORT=8080 bun start
```

## Interactive Test Interface

Open `scenarios.html` in your browser for an interactive UI with clickable links to all test scenarios:

```bash
open scenarios.html
```

This provides a visual interface to test all scenarios with a single click. Perfect for manual testing and demonstration.

## API Endpoint

### Single Main Endpoint

```
GET /api/reserves/
```

All test scenarios are triggered via query parameters on this single endpoint.

### Health Check

```
GET /health
```

Returns server health status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-27T00:00:00.000Z",
  "uptime": 123.456
}
```

## Quick Start Examples

### Normal Successful Response
```bash
curl http://localhost:3000/api/reserves/
```

### Test Size Limit (Exceeds 100 KB CRE Limit)
```bash
curl http://localhost:3000/api/reserves/?scenario=exceeds_limit
```

### Test Connection Timeout (11 seconds)
```bash
curl http://localhost:3000/api/reserves/?scenario=connection_timeout
```

### Test HTTP 500 Error
```bash
curl http://localhost:3000/api/reserves/?error=500
```

### Custom Delay (5 seconds)
```bash
curl http://localhost:3000/api/reserves/?delay=5000
```

### Custom Size (200 KB)
```bash
curl http://localhost:3000/api/reserves/?size=200
```

## Complete Test Scenarios

See **[TEST_CASES.md](TEST_CASES.md)** for the complete list of 25+ test scenarios including:

- **Size Limit Tests**: under_limit, at_limit, exceeds_limit, way_over_limit
- **Timeout Tests**: connection_timeout, capability_timeout, custom delays
- **HTTP Errors**: 400, 401, 403, 404, 429, 500, 502, 503, 504
- **Format Issues**: invalid_json, empty_response, wrong_content_type, partial_json
- **Data Validity**: missing_fields, invalid_types, null_values, negative_values, underbacked
- **Connection Issues**: connection_abort

## Query Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `scenario` | string | Named test scenario | `?scenario=exceeds_limit` |
| `delay` | number | Response delay in milliseconds | `?delay=5000` |
| `error` | number | HTTP error code to return | `?error=500` |
| `size` | number | Response size in KB | `?size=150` |

Parameters can be combined:
```bash
curl http://localhost:3000/api/reserves/?delay=2000&error=503
```

## Testing with CRE

Use this API in your CRE workflows to test error handling:

```typescript
import { http } from "@chainlink/cre-typescript-sdk/capabilities";

// Normal case
const response = await http.get("http://localhost:3000/api/reserves/");
const reserves = response.data;

// Test size limit (should fail in CRE)
try {
  const oversized = await http.get("http://localhost:3000/api/reserves/?scenario=exceeds_limit");
} catch (error) {
  console.error("Size limit exceeded:", error);
}

// Test timeout (should fail in CRE)
try {
  const timeout = await http.get("http://localhost:3000/api/reserves/?scenario=connection_timeout");
} catch (error) {
  console.error("Connection timeout:", error);
}

// Test error handling
try {
  const errorCase = await http.get("http://localhost:3000/api/reserves/?error=500");
} catch (error) {
  console.error("Server error:", error);
}
```

## CRE Limits Being Tested

This server is designed to test against these CRE constraints:

- **HTTP Response Size**: 100 KB max
- **HTTP Connection Timeout**: 10 seconds max
- **Capability Call Timeout**: 3 minutes max
- **HTTP Request Payload**: 10 KB max

## Normal Response Format

When no scenario is specified, the API returns normal proof of reserve data:

```json
{
  "timestamp": "2026-01-27T00:00:00.000Z",
  "assets": [
    {
      "assetId": "BTC",
      "name": "Bitcoin",
      "totalSupply": "1000000",
      "totalReserves": "1000000",
      "reserveRatio": 1.0,
      "unit": "BTC",
      "lastUpdated": "2026-01-27T00:00:00.000Z"
    },
    {
      "assetId": "ETH",
      "name": "Ethereum",
      "totalSupply": "5000000",
      "totalReserves": "5000000",
      "reserveRatio": 1.0,
      "unit": "ETH",
      "lastUpdated": "2026-01-27T00:00:00.000Z"
    },
    {
      "assetId": "USDC",
      "name": "USD Coin",
      "totalSupply": "100000000",
      "totalReserves": "100000000",
      "reserveRatio": 1.0,
      "unit": "USD",
      "lastUpdated": "2026-01-27T00:00:00.000Z"
    }
  ],
  "status": "FULLY_BACKED"
}
```

## Project Structure

```
por-api-server/
├── server.js          # Express server with all test scenarios
├── package.json       # Dependencies and scripts
├── scenarios.html     # Interactive browser UI for all test scenarios
├── TEST_CASES.md      # Complete test scenario documentation
├── README.md          # This file
└── .gitignore         # Git ignore rules
```

## Development

The server logs delays to the console for monitoring:

```bash
Delaying response by 5000ms
```

This helps track when timeout tests are running.

## License

MIT
