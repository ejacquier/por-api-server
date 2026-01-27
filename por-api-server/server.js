const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Helper function to generate large JSON payload
function generateLargePayload(sizeKB) {
  const baseData = {
    timestamp: new Date().toISOString(),
    assets: [
      {
        assetId: "BTC",
        name: "Bitcoin",
        totalSupply: "1000000",
        totalReserves: "1000000",
        reserveRatio: 1.0,
        unit: "BTC",
        lastUpdated: new Date().toISOString()
      }
    ],
    status: "FULLY_BACKED"
  };

  // Add padding to reach desired size
  const currentSize = JSON.stringify(baseData).length;
  const targetSize = sizeKB * 1024;
  const paddingNeeded = Math.max(0, targetSize - currentSize);

  baseData.padding = 'X'.repeat(paddingNeeded);

  return baseData;
}

// Normal reserve data
function getNormalReserveData() {
  return {
    timestamp: new Date().toISOString(),
    assets: [
      {
        assetId: "BTC",
        name: "Bitcoin",
        totalSupply: "1000000",
        totalReserves: "1000000",
        reserveRatio: 1.0,
        unit: "BTC",
        lastUpdated: new Date().toISOString()
      },
      {
        assetId: "ETH",
        name: "Ethereum",
        totalSupply: "5000000",
        totalReserves: "5000000",
        reserveRatio: 1.0,
        unit: "ETH",
        lastUpdated: new Date().toISOString()
      },
      {
        assetId: "USDC",
        name: "USD Coin",
        totalSupply: "100000000",
        totalReserves: "100000000",
        reserveRatio: 1.0,
        unit: "USD",
        lastUpdated: new Date().toISOString()
      }
    ],
    status: "FULLY_BACKED"
  };
}

// Under-backed reserve data
function getUnderbackedReserveData() {
  return {
    timestamp: new Date().toISOString(),
    assets: [
      {
        assetId: "BTC",
        name: "Bitcoin",
        totalSupply: "1000000",
        totalReserves: "900000",
        reserveRatio: 0.9,
        unit: "BTC",
        lastUpdated: new Date().toISOString()
      },
      {
        assetId: "ETH",
        name: "Ethereum",
        totalSupply: "5000000",
        totalReserves: "4500000",
        reserveRatio: 0.9,
        unit: "ETH",
        lastUpdated: new Date().toISOString()
      }
    ],
    status: "UNDER_BACKED"
  };
}

// Negative values data
function getNegativeReserveData() {
  return {
    timestamp: new Date().toISOString(),
    assets: [
      {
        assetId: "BTC",
        name: "Bitcoin",
        totalSupply: "1000000",
        totalReserves: "-100000",
        reserveRatio: -0.1,
        unit: "BTC",
        lastUpdated: new Date().toISOString()
      }
    ],
    status: "ERROR"
  };
}

// Routes

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Main reserves endpoint with test scenarios
app.get('/api/reserves/', async (req, res) => {
  const { scenario, delay, error, size } = req.query;

  // Handle delay parameter (in milliseconds)
  if (delay) {
    const delayMs = parseInt(delay, 10);
    console.log(`Delaying response by ${delayMs}ms`);
    await new Promise(resolve => setTimeout(resolve, delayMs));
  }

  // Handle HTTP error codes
  if (error) {
    const errorCode = parseInt(error, 10);
    const errorMessages = {
      400: { error: 'Bad Request', message: 'The request was invalid' },
      401: { error: 'Unauthorized', message: 'Authentication required' },
      403: { error: 'Forbidden', message: 'Access denied' },
      404: { error: 'Not Found', message: 'Resource not found' },
      429: { error: 'Too Many Requests', message: 'Rate limit exceeded' },
      500: { error: 'Internal Server Error', message: 'An internal error occurred' },
      502: { error: 'Bad Gateway', message: 'Invalid response from upstream server' },
      503: { error: 'Service Unavailable', message: 'Service temporarily unavailable' },
      504: { error: 'Gateway Timeout', message: 'Upstream server timeout' }
    };

    return res.status(errorCode).json(errorMessages[errorCode] || { error: 'Error', message: 'An error occurred' });
  }

  // Handle size parameter
  if (size) {
    const sizeKB = parseInt(size, 10);
    const data = generateLargePayload(sizeKB);
    return res.json(data);
  }

  // Handle named scenarios
  switch (scenario) {
    // Size limit scenarios
    case 'under_limit':
      return res.json(generateLargePayload(99));

    case 'at_limit':
      return res.json(generateLargePayload(100));

    case 'exceeds_limit':
      return res.json(generateLargePayload(150));

    case 'way_over_limit':
      return res.json(generateLargePayload(500));

    // Timeout scenarios
    case 'connection_timeout':
      // 11 seconds - exceeds 10 second HTTP connection timeout
      await new Promise(resolve => setTimeout(resolve, 11000));
      return res.json(getNormalReserveData());

    case 'under_connection_timeout':
      // 9 seconds - should work
      await new Promise(resolve => setTimeout(resolve, 9000));
      return res.json(getNormalReserveData());

    // Response format scenarios
    case 'invalid_json':
      res.set('Content-Type', 'application/json');
      return res.send('{"timestamp": "2026-01-27", "assets": [invalid json here}');

    case 'empty_response':
      return res.send('');

    case 'wrong_content_type':
      res.set('Content-Type', 'text/plain');
      return res.send(JSON.stringify(getNormalReserveData()));

    case 'partial_json':
      res.set('Content-Type', 'application/json');
      const partial = JSON.stringify(getNormalReserveData());
      return res.send(partial.substring(0, partial.length / 2));

    case 'missing_fields':
      return res.json({
        timestamp: new Date().toISOString()
        // Missing assets and status fields
      });

    case 'invalid_types':
      return res.json({
        timestamp: 12345, // Should be string
        assets: "not an array", // Should be array
        status: true // Should be string
      });

    case 'null_values':
      return res.json({
        timestamp: null,
        assets: null,
        status: null
      });

    // Data validity scenarios
    case 'negative_values':
      return res.json(getNegativeReserveData());

    case 'underbacked':
      return res.json(getUnderbackedReserveData());

    // Connection abort scenario
    case 'connection_abort':
      res.write('{"timestamp": "');
      await new Promise(resolve => setTimeout(resolve, 100));
      // Destroy the connection mid-response
      req.socket.destroy();
      return;

    // Default: normal successful response
    default:
      return res.json(getNormalReserveData());
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.path,
    message: 'Use /api/reserves/ with optional query parameters. See TEST_CASES.md for details.'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Proof of Reserve API server running on port ${PORT}`);
  console.log(`Main endpoint: http://localhost:${PORT}/api/reserves/`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`See TEST_CASES.md for all test scenarios`);
});
