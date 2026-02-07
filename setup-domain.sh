#!/usr/bin/env bash
set -euo pipefail

# ============================================
# FitForce — Domain Setup Script
# Usage: ./setup-domain.sh <domain> [staging|prod]
# Example: ./setup-domain.sh fitforce.com prod
# ============================================

DOMAIN="${1:-}"
STAGE="${2:-prod}"
STACK_NAME="fitforce-${STAGE}"
REGION="${AWS_REGION:-us-east-1}"

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: ./setup-domain.sh <domain> [staging|prod]"
  echo "Example: ./setup-domain.sh fitforce.com prod"
  exit 1
fi

echo "==> Setting up domain: $DOMAIN for $STACK_NAME"

# --- Check prerequisites ---
for cmd in aws jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not installed."
    exit 1
  fi
done

# --- Get CloudFront distribution ID from stack ---
get_output() {
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" \
    --output text
}

CF_DIST_ID=$(get_output "CloudFrontDistributionId")
CF_DOMAIN=$(get_output "CloudFrontDomain")

if [[ -z "$CF_DIST_ID" ]]; then
  echo "Error: Could not find CloudFront distribution. Run ./deploy.sh first."
  exit 1
fi

echo "   CloudFront Distribution: $CF_DIST_ID"
echo "   CloudFront Domain: $CF_DOMAIN"

# --- Step 1: Check for existing certificate or request new one ---
echo ""
echo "==> Step 1: SSL Certificate"

CERT_ARN=$(aws acm list-certificates \
  --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" \
  --output text 2>/dev/null || echo "")

if [[ -n "$CERT_ARN" && "$CERT_ARN" != "None" ]]; then
  echo "   Found existing certificate: $CERT_ARN"
else
  echo "   Requesting new certificate for $DOMAIN and *.$DOMAIN..."
  CERT_ARN=$(aws acm request-certificate \
    --domain-name "$DOMAIN" \
    --subject-alternative-names "*.$DOMAIN" \
    --validation-method DNS \
    --region us-east-1 \
    --query 'CertificateArn' \
    --output text)
  echo "   Certificate ARN: $CERT_ARN"
  echo "   Waiting for certificate details..."
  sleep 5
fi

# --- Step 2: Get DNS validation records ---
echo ""
echo "==> Step 2: DNS Validation Records"

VALIDATION_RECORDS=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[*].ResourceRecord' \
  --output json)

echo ""
echo "   Add these CNAME records to your DNS provider:"
echo "   =============================================="
echo "$VALIDATION_RECORDS" | jq -r '.[] | "   Name:  \(.Name)\n   Value: \(.Value)\n"'

# --- Step 3: Wait for certificate validation ---
echo "==> Step 3: Waiting for certificate validation..."
echo "   (Add the DNS records above, then wait for validation)"
echo ""

CERT_STATUS="PENDING_VALIDATION"
WAIT_COUNT=0
MAX_WAIT=60  # 10 minutes max

while [[ "$CERT_STATUS" == "PENDING_VALIDATION" && $WAIT_COUNT -lt $MAX_WAIT ]]; do
  CERT_STATUS=$(aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --region us-east-1 \
    --query 'Certificate.Status' \
    --output text)

  if [[ "$CERT_STATUS" == "ISSUED" ]]; then
    echo "   Certificate validated and issued!"
    break
  fi

  echo "   Status: $CERT_STATUS (waiting... press Ctrl+C to skip and continue later)"
  sleep 10
  ((WAIT_COUNT++))
done

if [[ "$CERT_STATUS" != "ISSUED" ]]; then
  echo ""
  echo "   Certificate not yet validated. You can:"
  echo "   1. Add the DNS records above and run this script again"
  echo "   2. Check status: aws acm describe-certificate --certificate-arn $CERT_ARN --region us-east-1"
  echo ""
  read -p "   Continue anyway to see remaining steps? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

# --- Step 4: Update CloudFront distribution ---
echo ""
echo "==> Step 4: Updating CloudFront distribution"

# Get current config
TMPDIR=$(mktemp -d)
aws cloudfront get-distribution-config --id "$CF_DIST_ID" > "$TMPDIR/cf-config-full.json"

ETAG=$(jq -r '.ETag' "$TMPDIR/cf-config-full.json")
jq '.DistributionConfig' "$TMPDIR/cf-config-full.json" > "$TMPDIR/cf-config.json"

# Update the config with domain and certificate
jq --arg domain "$DOMAIN" --arg cert "$CERT_ARN" '
  .Aliases = {
    "Quantity": 2,
    "Items": [$domain, "www." + $domain]
  } |
  .ViewerCertificate = {
    "ACMCertificateArn": $cert,
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021",
    "Certificate": $cert,
    "CertificateSource": "acm"
  }
' "$TMPDIR/cf-config.json" > "$TMPDIR/cf-config-updated.json"

if [[ "$CERT_STATUS" == "ISSUED" ]]; then
  echo "   Applying CloudFront configuration..."
  aws cloudfront update-distribution \
    --id "$CF_DIST_ID" \
    --distribution-config file://"$TMPDIR/cf-config-updated.json" \
    --if-match "$ETAG" \
    --output text > /dev/null
  echo "   CloudFront updated! (may take 5-10 minutes to deploy)"
else
  echo "   Skipping CloudFront update (certificate not yet issued)"
  echo "   Run this script again after certificate is validated"
fi

rm -rf "$TMPDIR"

# --- Step 5: Show final DNS records ---
echo ""
echo "==> Step 5: Final DNS Configuration"
echo ""
echo "   Add these records to your DNS provider:"
echo "   ========================================"
echo ""
echo "   Root domain ($DOMAIN):"
echo "   Type:  ALIAS or ANAME (if supported) or CNAME flattening"
echo "   Name:  @ (or $DOMAIN)"
echo "   Value: $CF_DOMAIN"
echo ""
echo "   WWW subdomain:"
echo "   Type:  CNAME"
echo "   Name:  www"
echo "   Value: $CF_DOMAIN"
echo ""
echo "   Note: If your DNS provider doesn't support ALIAS records for"
echo "   root domains, consider using AWS Route 53 or Cloudflare."
echo ""

# --- Done ---
echo "============================================"
echo "  Domain setup complete!"
echo ""
echo "  Certificate: $CERT_ARN"
echo "  CloudFront:  $CF_DOMAIN"
echo "  Domain:      https://$DOMAIN"
echo "============================================"
