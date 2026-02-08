#!/usr/bin/env bash
set -euo pipefail

# ============================================
# FitForce — Deployment Script
# Usage: ./deploy.sh [staging|prod]
# ============================================

STAGE="${1:-prod}"
STACK_NAME="fitforce-${STAGE}"
REGION="${AWS_REGION:-us-east-1}"
SAM_BUCKET=""  # Set this or let SAM create a managed bucket

echo "==> Deploying FitForce ($STAGE) to $REGION"

# --- Check prerequisites ---
for cmd in aws sam; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not installed."
    exit 1
  fi
done

# --- Build & Deploy SAM stack ---
echo "==> Building SAM application..."
sam build --template-file template.yaml --use-container

echo "==> Deploying SAM stack: $STACK_NAME"
SAM_DEPLOY_ARGS=(
  --stack-name "$STACK_NAME"
  --region "$REGION"
  --capabilities CAPABILITY_IAM
  --resolve-s3
  --no-confirm-changeset
  --parameter-overrides "Stage=$STAGE"
)

if ! sam deploy "${SAM_DEPLOY_ARGS[@]}" 2>&1; then
  echo "   (No infrastructure changes — continuing with static file upload)"
fi

# --- Get stack outputs ---
echo "==> Fetching stack outputs..."
get_output() {
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" \
    --output text
}

API_URL=$(get_output "ApiUrl")
BUCKET_NAME=$(get_output "WebsiteBucketName")
CF_DOMAIN=$(get_output "CloudFrontDomain")
CF_DIST_ID=$(get_output "CloudFrontDistributionId")

echo "   API URL:      $API_URL"
echo "   S3 Bucket:    $BUCKET_NAME"
echo "   CloudFront:   https://$CF_DOMAIN"

# --- Inject API URL into script.js and upload static files ---
echo "==> Uploading static files to S3..."

# Create a temp copy of script.js with the real API URL
TMPDIR=$(mktemp -d)
cp index.html style.css "$TMPDIR/"
cp favicon.svg og-image.svg og-image.png "$TMPDIR/" 2>/dev/null || true
cp favicon-32x32.png favicon-16x16.png apple-touch-icon.png "$TMPDIR/" 2>/dev/null || true
cp robots.txt sitemap.xml "$TMPDIR/" 2>/dev/null || true
sed "s|var API_URL = '';|var API_URL = '${API_URL}';|" script.js > "$TMPDIR/script.js"

aws s3 sync "$TMPDIR/" "s3://$BUCKET_NAME/" \
  --region "$REGION" \
  --delete \
  --cache-control "public, max-age=3600"

# Set longer cache for CSS/JS (they'll get invalidated)
aws s3 cp "$TMPDIR/style.css" "s3://$BUCKET_NAME/style.css" \
  --region "$REGION" \
  --cache-control "public, max-age=86400" \
  --content-type "text/css"

aws s3 cp "$TMPDIR/script.js" "s3://$BUCKET_NAME/script.js" \
  --region "$REGION" \
  --cache-control "public, max-age=86400" \
  --content-type "application/javascript"

rm -rf "$TMPDIR"

# --- Invalidate CloudFront cache ---
echo "==> Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id "$CF_DIST_ID" \
  --paths "/*" \
  --region "$REGION" \
  --output text > /dev/null

# --- Done ---
echo ""
echo "============================================"
echo "  Deployment complete!"
echo ""
echo "  Site:  https://$CF_DOMAIN"
echo "  API:   $API_URL"
echo "============================================"
