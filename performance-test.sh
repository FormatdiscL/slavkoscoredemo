#!/bin/bash

set -e

echo "🧪 Running performance tests..."

# Define the deployment URL
if [ -z "$DEPLOYMENT_URL" ]; then
  DEPLOYMENT_URL=$(vercel --token "$VERCEL_TOKEN" --scope "$VERCEL_ORG_ID" | grep -o 'https://[^ ]*' | head -1)
  echo "Using deployment URL: $DEPLOYMENT_URL"
fi

# Define test parameters
CONCURRENT_USERS=50
TEST_DURATION=30 # seconds
ENDPOINTS=(
  "/"
  "/api/health"
  "/api/status"
)

# Install k6 if not already installed
if ! command -v k6 &> /dev/null; then
  echo "Installing k6..."
  curl -s https://github.com/grafana/k6/releases/download/v0.42.0/k6-v0.42.0-linux-amd64.tar.gz | tar xz
  sudo cp k6-v0.42.0-linux-amd64/k6 /usr/local/bin/
fi

# Create a temporary k6 script
cat > /tmp/performance-test.js << EOF
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: ${CONCURRENT_USERS},
  duration: '${TEST_DURATION}s',
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.01'],   // Less than 1% of requests should fail
  },
};

export default function() {
  const endpoints = [
    '${DEPLOYMENT_URL}/',
    '${DEPLOYMENT_URL}/api/health',
    '${DEPLOYMENT_URL}/api/status',
  ];
  
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  const res = http.get(endpoint);
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
EOF

# Run the performance test
echo "Running performance test with ${CONCURRENT_USERS} concurrent users for ${TEST_DURATION} seconds..."
k6 run /tmp/performance-test.js

# Clean up
rm /tmp/performance-test.js

echo "✅ Performance tests completed!"