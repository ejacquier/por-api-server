# API Test Cases for CRE Workflow Testing

This document lists all available test scenarios for testing Chainlink Runtime Environment (CRE) workflow error handling and behavior with the Proof of Reserve API.

## Endpoint

All test scenarios use the single endpoint:
```
GET http://localhost:3000/api/reserves/
```

## CRE Limits Being Tested

Based on CRE documentation:
- **HTTP Response Size Limit**: 100 KB
- **HTTP Connection Timeout**: 10 seconds
- **Capability Call Timeout**: 3 minutes
- **HTTP Request Payload**: Max 10 KB

---

## 1. Size Limit Test Cases

Test scenarios that target the **100 KB HTTP response size limit**.

### 1.1 Under Limit (Should Work)
```bash
GET /api/reserves/?scenario=under_limit
# or
GET /api/reserves/?size=99
```
**Expected**: Returns ~99 KB payload successfully

---

### 1.2 At Limit (Edge Case)
```bash
GET /api/reserves/?scenario=at_limit
# or
GET /api/reserves/?size=100
```
**Expected**: Returns exactly 100 KB payload (edge case)

---

### 1.3 Exceeds Limit (Should Fail in CRE)
```bash
GET /api/reserves/?scenario=exceeds_limit
# or
GET /api/reserves/?size=150
```
**Expected**: Returns 150 KB payload - **CRE should fail** with size limit error

---

### 1.4 Way Over Limit (Should Fail in CRE)
```bash
GET /api/reserves/?scenario=way_over_limit
# or
GET /api/reserves/?size=500
```
**Expected**: Returns 500 KB payload - **CRE should fail** with size limit error

---

### 1.5 Custom Size
```bash
GET /api/reserves/?size=<KB>
```
**Example**: `?size=200` for 200 KB response
**Use**: Test specific size thresholds

---

## 2. Timeout Test Cases

Test scenarios that target the **10 second connection timeout** and **3 minute capability timeout**.

### 2.1 Connection Timeout (Should Fail in CRE)
```bash
GET /api/reserves/?scenario=connection_timeout
```
**Delay**: 11 seconds
**Expected**: **CRE should timeout** (exceeds 10 second HTTP connection timeout)

---

### 2.2 Capability Timeout (Should Fail in CRE)
```bash
GET /api/reserves/?scenario=capability_timeout
```
**Delay**: 3.5 minutes (210 seconds)
**Expected**: **CRE should timeout** (exceeds 3 minute capability call timeout)

---

### 2.3 Under Connection Timeout (Should Work)
```bash
GET /api/reserves/?scenario=under_connection_timeout
```
**Delay**: 9 seconds
**Expected**: Should complete successfully (just under timeout)

---

### 2.4 Under Capability Timeout (Should Work But Slow)
```bash
GET /api/reserves/?scenario=under_capability_timeout
```
**Delay**: 2.5 minutes (150 seconds)
**Expected**: Should complete successfully but very slow

---

### 2.5 Custom Delay
```bash
GET /api/reserves/?delay=<milliseconds>
```
**Examples**:
- `?delay=5000` - 5 second delay
- `?delay=12000` - 12 second delay (should timeout)
- `?delay=1000` - 1 second delay

**Use**: Test specific timing thresholds

---

## 3. HTTP Error Code Test Cases

Test scenarios for different HTTP error responses.

### 3.1 Bad Request (400)
```bash
GET /api/reserves/?error=400
```
**Response**: 400 Bad Request with error message

---

### 3.2 Unauthorized (401)
```bash
GET /api/reserves/?error=401
```
**Response**: 401 Unauthorized - authentication required

---

### 3.3 Forbidden (403)
```bash
GET /api/reserves/?error=403
```
**Response**: 403 Forbidden - access denied

---

### 3.4 Not Found (404)
```bash
GET /api/reserves/?error=404
```
**Response**: 404 Not Found - resource not found

---

### 3.5 Too Many Requests (429)
```bash
GET /api/reserves/?error=429
```
**Response**: 429 Too Many Requests - rate limit exceeded

---

### 3.6 Internal Server Error (500)
```bash
GET /api/reserves/?error=500
```
**Response**: 500 Internal Server Error

---

### 3.7 Bad Gateway (502)
```bash
GET /api/reserves/?error=502
```
**Response**: 502 Bad Gateway - invalid upstream response

---

### 3.8 Service Unavailable (503)
```bash
GET /api/reserves/?error=503
```
**Response**: 503 Service Unavailable - service temporarily down

---

### 3.9 Gateway Timeout (504)
```bash
GET /api/reserves/?error=504
```
**Response**: 504 Gateway Timeout - upstream timeout

---

## 4. Response Format Test Cases

Test scenarios for malformed or invalid response formats.

### 4.1 Invalid JSON
```bash
GET /api/reserves/?scenario=invalid_json
```
**Response**: Malformed JSON that cannot be parsed
**Expected**: CRE should fail with JSON parse error

---

### 4.2 Empty Response
```bash
GET /api/reserves/?scenario=empty_response
```
**Response**: 200 OK but empty body
**Expected**: CRE should handle empty response

---

### 4.3 Wrong Content-Type
```bash
GET /api/reserves/?scenario=wrong_content_type
```
**Response**: Valid JSON but with `Content-Type: text/plain` header
**Expected**: Test if CRE validates content-type

---

### 4.4 Partial JSON
```bash
GET /api/reserves/?scenario=partial_json
```
**Response**: JSON cut off mid-stream (incomplete)
**Expected**: CRE should fail with parse error

---

### 4.5 Missing Required Fields
```bash
GET /api/reserves/?scenario=missing_fields
```
**Response**: Valid JSON but missing `assets` and `status` fields
**Expected**: Test CRE's field validation

---

### 4.6 Invalid Data Types
```bash
GET /api/reserves/?scenario=invalid_types
```
**Response**: JSON with wrong data types (number instead of string, etc.)
**Expected**: Test CRE's type checking

---

### 4.7 Null Values
```bash
GET /api/reserves/?scenario=null_values
```
**Response**: JSON with null values in all fields
**Expected**: Test CRE's null handling

---

## 5. Data Validity Test Cases

Test scenarios for logically invalid but structurally valid data.

### 5.1 Negative Reserve Values
```bash
GET /api/reserves/?scenario=negative_values
```
**Response**: Valid JSON with negative reserve amounts
**Expected**: Test business logic validation

---

### 5.2 Under-backed Reserves
```bash
GET /api/reserves/?scenario=underbacked
```
**Response**: Valid JSON with reserve ratio < 1.0
**Expected**: Test reserve ratio validation

---

## 6. Connection Issues

### 6.1 Connection Abort
```bash
GET /api/reserves/?scenario=connection_abort
```
**Response**: Connection drops mid-response
**Expected**: CRE should handle connection errors gracefully

---

## 7. Normal/Successful Cases

### 7.1 Successful Response
```bash
GET /api/reserves/
# or
GET /api/reserves/?scenario=success
```
**Response**: Normal, valid proof of reserve data
**Expected**: Should work perfectly (control test case)

---

## Combined Parameters

You can combine certain parameters:

### Delayed Error Response
```bash
GET /api/reserves/?delay=2000&error=500
```
**Result**: 2 second delay, then 500 error

---

### Delayed Success
```bash
GET /api/reserves/?delay=3000
```
**Result**: 3 second delay, then normal response

---

## Quick Reference Table

| Scenario | URL | Expected CRE Behavior |
|----------|-----|----------------------|
| Normal | `/api/reserves/` | ✅ Success |
| Under limit | `?scenario=under_limit` | ✅ Success (99 KB) |
| At limit | `?scenario=at_limit` | ⚠️ Edge case (100 KB) |
| Exceeds limit | `?scenario=exceeds_limit` | ❌ Size limit error (150 KB) |
| Way over | `?scenario=way_over_limit` | ❌ Size limit error (500 KB) |
| Connection timeout | `?scenario=connection_timeout` | ❌ Connection timeout (11s) |
| Capability timeout | `?scenario=capability_timeout` | ❌ Capability timeout (3.5m) |
| Under conn timeout | `?scenario=under_connection_timeout` | ✅ Success but slow (9s) |
| Under cap timeout | `?scenario=under_capability_timeout` | ✅ Success but very slow (2.5m) |
| HTTP 500 | `?error=500` | ❌ Server error |
| HTTP 503 | `?error=503` | ❌ Service unavailable |
| HTTP 429 | `?error=429` | ❌ Rate limit |
| Invalid JSON | `?scenario=invalid_json` | ❌ Parse error |
| Empty response | `?scenario=empty_response` | ⚠️ Empty data |
| Partial JSON | `?scenario=partial_json` | ❌ Parse error |
| Missing fields | `?scenario=missing_fields` | ⚠️ Validation error |
| Invalid types | `?scenario=invalid_types` | ⚠️ Type error |
| Negative values | `?scenario=negative_values` | ⚠️ Business logic error |
| Under-backed | `?scenario=underbacked` | ⚠️ Business logic warning |
| Connection abort | `?scenario=connection_abort` | ❌ Connection error |

**Legend:**
- ✅ Should succeed
- ❌ Should fail with error
- ⚠️ Edge case - depends on validation logic

---

## Testing with cURL

You can test all scenarios with cURL:

```bash
# Normal response
curl http://localhost:3000/api/reserves/

# Size limit test
curl http://localhost:3000/api/reserves/?scenario=exceeds_limit

# Timeout test (will wait)
curl http://localhost:3000/api/reserves/?scenario=connection_timeout

# Error code test
curl http://localhost:3000/api/reserves/?error=500

# Custom delay
curl http://localhost:3000/api/reserves/?delay=5000

# Combined parameters
curl http://localhost:3000/api/reserves/?delay=2000&error=503
```

---

## Testing with CRE Workflow

Example CRE workflow snippet to test these scenarios:

```typescript
import { http } from "@chainlink/cre-typescript-sdk/capabilities";

// Test normal case
const normalResponse = await http.get("http://localhost:3000/api/reserves/");

// Test size limit (should fail)
const oversizedResponse = await http.get("http://localhost:3000/api/reserves/?scenario=exceeds_limit");

// Test timeout (should fail)
const timeoutResponse = await http.get("http://localhost:3000/api/reserves/?scenario=connection_timeout");

// Test error handling
const errorResponse = await http.get("http://localhost:3000/api/reserves/?error=500");
```

---

## Notes

1. **Size scenarios** use padding to generate exact payload sizes
2. **Timeout scenarios** use actual delays - be patient when testing
3. **Error codes** return immediately with the specified HTTP status
4. **Format scenarios** test JSON parsing and content-type handling
5. **Data validity** scenarios test business logic validation
6. All scenarios return appropriate HTTP status codes and response bodies
7. The server logs delays to console for monitoring

---

## Health Check

To verify the server is running:
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-27T...",
  "uptime": 123.456
}
```
