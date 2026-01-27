# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a testing suite for Chainlink Runtime Environment (CRE) Proof of Reserve workflows. It consists of:

- **por-api-server/**: Mock REST API server that simulates various error conditions and edge cases
- **cre/**: Directory for CRE workflow code (placeholder, to be developed)

## Commands

### API Server

```bash
# Install dependencies
cd por-api-server && bun install

# Start server (runs on port 3000 by default)
bun start

# Development with auto-reload
bun run dev

# Custom port
PORT=8080 bun start
```

### Manual Testing

Open `por-api-server/scenarios.html` in browser for interactive test UI.

## Architecture

### API Server (por-api-server/server.js)

Single Express endpoint `/api/reserves/` with query parameters to trigger test scenarios:

- `?scenario=<name>` - Named scenarios (exceeds_limit, connection_timeout, invalid_json, etc.)
- `?delay=<ms>` - Custom response delay
- `?error=<code>` - HTTP error codes (400, 401, 403, 404, 429, 500, 502, 503, 504)
- `?size=<kb>` - Custom response size in KB

### CRE Limits Being Tested

| Limit                    | Value       |
| ------------------------ | ----------- |
| HTTP Response Size       | 100 KB max  |
| HTTP Connection Timeout | 10 seconds |
| Capability Call Timeout | 3 minutes |
| HTTP Request Payload | 10 KB max |

### Test Scenario Categories

- **Size limits**: under_limit (99KB), at_limit (100KB), exceeds_limit (150KB), way_over_limit (500KB)
- **Timeouts**: connection_timeout (11s), capability_timeout (3.5min), under_connection_timeout (9s)
- **Format issues**: invalid_json, empty_response, wrong_content_type, partial_json, missing_fields, invalid_types, null_values
- **Data validity**: negative_values, underbacked
- **Connection issues**: connection_abort

## CRE Documentation

**Always fetch and reference this documentation when working with CRE workflows:**

[CRE TypeScript SDK Documentation](https://docs.chain.link/cre/llms-full-ts.txt)
