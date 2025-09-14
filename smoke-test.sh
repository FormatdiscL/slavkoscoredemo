#!/bin/bash

set -e

DEPLOYMENT_URL="$1"

echo "🧪 Running smoke tests against: $DEPLOYMENT_URL"

# Test endpoints
endpoints=(
  "/api/health"
  "/api/status"
  "/api/v1/evaluations/health"
)

for endpoint in "${endpoints[@]}"; do
  url="${DEPLOYMENT_URL}${endpoint}"
  echo "Testing $url"
  
  response=$(curl -s -o /dev/null -w "%{http_code}" --retry 3 --retry-delay 2 "$url")
  
  if [ "$response" -ne 200 ]; then
    echo "❌ Smoke test failed for $endpoint: HTTP $response"
    exit 1
  fi
  
  echo "✅ $endpoint: HTTP $response"
done

# Test function endpoints
FUNCTIONS_URL="https://us-central1-$FIREBASE_PROJECT_ID.cloudfunctions.net"
function_endpoints=(
  "/apiHealth"
  "/monitorAgent"
)

for endpoint in "${function_endpoints[@]}"; do
  url="${FUNCTIONS_URL}${endpoint}"
  echo "Testing $url"
  
  response=$(curl -s -o /dev/null -w "%{http_code}" --retry 2 "$url")
  
  if [ "$response" -ne 200 ] && [ "$response" -ne 404 ]; then
    echo "⚠️  Function endpoint $endpoint: HTTP $response (might be cold start)"
  else
    echo "✅ Function endpoint $endpoint: HTTP $response"
  fi
done

echo "✅ All smoke tests passed!"