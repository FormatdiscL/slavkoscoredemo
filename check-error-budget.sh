#!/bin/bash

# Check if performance metrics are within acceptable bounds
echo "📊 Checking performance budgets..."

# Define performance thresholds
MAX_P95_RESPONSE_TIME=300  # 300ms
MAX_ERROR_RATE=0.01        # 1%
MIN_THROUGHPUT=1000        # 1000 requests/minute

# Get current metrics (simplified - integrate with your monitoring tool)
CURRENT_P95=$(curl -s "https://monitoring-api.example.com/metrics/p95")
CURRENT_ERROR_RATE=$(curl -s "https://monitoring-api.example.com/metrics/errorRate")
CURRENT_THROUGHPUT=$(curl -s "https://monitoring-api.example.com/metrics/throughput")

# Check thresholds
if (( $(echo "$CURRENT_P95 > $MAX_P95_RESPONSE_TIME" | bc -l) )); then
  echo "❌ P95 response time exceeded: $CURRENT_P95 ms > $MAX_P95_RESPONSE_TIME ms"
  exit 1
fi

if (( $(echo "$CURRENT_ERROR_RATE > $MAX_ERROR_RATE" | bc -l) )); then
  echo "❌ Error rate exceeded: $CURRENT_ERROR_RATE > $MAX_ERROR_RATE"
  exit 1
fi

if (( $(echo "$CURRENT_THROUGHPUT < $MIN_THROUGHPUT" | bc -l) )); then
  echo "❌ Throughput too low: $CURRENT_THROUGHPUT < $MIN_THROUGHPUT"
  exit 1
fi

echo "✅ All performance metrics within acceptable bounds:"
echo "   P95 Response Time: $CURRENT_P95 ms"
echo "   Error Rate: $CURRENT_ERROR_RATE"
echo "   Throughput: $CURRENT_THROUGHPUT req/min"