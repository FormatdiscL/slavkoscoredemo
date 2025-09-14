#!/bin/bash

set -e

echo "🚀 Starting SlavkoKernel production deployment..."
echo "📅 $(date)"
echo "=============================================="

# Load environment variables
if [ -f .env.production ]; then
  export $(cat .env.production | grep -v '^#' | xargs)
  echo "✅ Loaded production environment variables"
else
  echo "❌ .env.production file not found"
  exit 1
fi

# Validate required environment variables
required_vars=(
  "FIREBASE_PROJECT_ID"
  "DEEPSEEK_API_KEY"
  "STRIPE_API_KEY"
  "VERCEL_TOKEN"
  "VERCEL_ORG_ID"
  "VERCEL_PROJECT_ID"
  "SLACK_WEBHOOK_URL"
)

for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ Missing required environment variable: $var"
    exit 1
  fi
done

# Function for error handling and notifications
notify_slack() {
  local message="$1"
  local color="$2"
  curl -s -X POST -H 'Content-type: application/json' \
    --data "{&quot;text&quot;:&quot;$message&quot;,&quot;attachments&quot;:[{&quot;color&quot;:&quot;$color&quot;,&quot;text&quot;:&quot;Environment: production\\nTimestamp: $(date)&quot;}]}" \
    "$SLACK_WEBHOOK_URL" > /dev/null
}

# Set up error trap
trap 'notify_slack "❌ SlavkoKernel deployment failed" "danger"; exit 1' ERR

# Deploy Firebase backend
echo "📦 Deploying Firebase backend..."
cd firebase

# Set Firebase config
echo "🔧 Configuring Firebase environment variables..."
firebase functions:config:set \
  deepseek.api_key="$DEEPSEEK_API_KEY" \
  stripe.api_key="$STRIPE_API_KEY" \
  app.env="production" \
  --project "$FIREBASE_PROJECT_ID"

# Deploy Firebase services
echo "🚀 Deploying Firebase functions and Firestore rules..."
firebase deploy --only functions,firestore --project "$FIREBASE_PROJECT_ID" --force

# Run quick smoke test on deployed functions
echo "🧪 Running smoke tests..."
DEPLOYED_URL="https://us-central1-${FIREBASE_PROJECT_ID}.cloudfunctions.net"
curl -s --retry 3 --retry-delay 5 "${DEPLOYED_URL}/apiHealth" | grep -q "ok" || {
  echo "❌ Smoke test failed: API health check"
  exit 1
}

# Deploy Next.js frontend
echo "🌐 Deploying Next.js frontend..."
cd ../web

# Build the application with production settings
echo "🏗 Building production application..."
NEXT_PUBLIC_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
NEXT_PUBLIC_APP_ENV="production" \
npm run build

# Deploy to Vercel
echo "🚀 Deploying to Vercel..."
vercel --prod --confirm --token "$VERCEL_TOKEN" --scope "$VERCEL_ORG_ID" --build-env NEXT_PUBLIC_APP_ENV=production

# Get deployment URL
DEPLOYMENT_URL=$(vercel --token "$VERCEL_TOKEN" --scope "$VERCEL_ORG_ID" | grep -o 'https://[^ ]*' | head -1)

# Run comprehensive smoke tests
echo "🧪 Running comprehensive smoke tests..."
../scripts/smoke-test.sh "$DEPLOYMENT_URL"

# Update deployment status
echo "✅ Deployment successful!"
notify_slack "✅ SlavkoKernel deployed successfully! 🚀\n\n• Frontend: $DEPLOYMENT_URL\n• Backend: ${DEPLOYED_URL}\n• Environment: production" "good"

# Performance monitoring setup
echo "📊 Setting up performance monitoring..."
curl -s -X POST "${DEPLOYED_URL}/setupMonitoring" -H "Content-Type: application/json" -d '{
  "alerts": {
    "responseTime": 300,
    "errorRate": 0.01,
    "throughput": 1000
  }
}'

echo "=============================================="
echo "🎉 Deployment completed successfully!"
echo "🌐 Frontend URL: $DEPLOYMENT_URL"
echo "🔧 Backend URL: $DEPLOYED_URL"
echo "📅 $(date)"