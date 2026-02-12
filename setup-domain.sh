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

# --- Step 5: Route 53 DNS Records ---
echo ""
echo "==> Step 5: Route 53 DNS Configuration"

# Find the hosted zone for the domain
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "$DOMAIN" \
  --query "HostedZones[?Name=='${DOMAIN}.'].Id" \
  --output text | sed 's|/hostedzone/||')

if [[ -z "$HOSTED_ZONE_ID" || "$HOSTED_ZONE_ID" == "None" ]]; then
  echo "   Error: No Route 53 hosted zone found for $DOMAIN"
  echo "   Create one first: aws route53 create-hosted-zone --name $DOMAIN --caller-reference $(date +%s)"
  exit 1
fi

echo "   Hosted Zone ID: $HOSTED_ZONE_ID"

# Google Search Console verification TXT record
GOOGLE_VERIFICATION="google-site-verification=ZBmbydceaQ8fhVf4Sb-ZhbGmpaiYMzr4kpq6jJ2yhKY"

echo "   Adding Google Search Console verification TXT record..."
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'"$DOMAIN"'",
        "Type": "TXT",
        "TTL": 300,
        "ResourceRecords": [{"Value": "\"'"$GOOGLE_VERIFICATION"'\""}]
      }
    }]
  }' --output text > /dev/null
echo "   Google verification TXT record added."

# Root domain A record (alias to CloudFront)
echo "   Adding root domain A record (alias to CloudFront)..."
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'"$DOMAIN"'",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "'"$CF_DOMAIN"'",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }' --output text > /dev/null
echo "   Root domain A record added."

# WWW CNAME record (alias to CloudFront)
echo "   Adding www subdomain A record (alias to CloudFront)..."
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "www.'"$DOMAIN"'",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "'"$CF_DOMAIN"'",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }' --output text > /dev/null
echo "   WWW A record added."

# Also add ACM validation CNAME records to Route 53
echo "   Adding ACM validation CNAME records..."
VALIDATION_JSON=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[*].ResourceRecord' \
  --output json)

CHANGES="["
FIRST=true
for row in $(echo "$VALIDATION_JSON" | jq -c '.[]'); do
  CNAME_NAME=$(echo "$row" | jq -r '.Name')
  CNAME_VALUE=$(echo "$row" | jq -r '.Value')
  if [[ "$FIRST" != true ]]; then CHANGES+=","; fi
  CHANGES+='{"Action":"UPSERT","ResourceRecordSet":{"Name":"'"$CNAME_NAME"'","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"'"$CNAME_VALUE"'"}]}}'
  FIRST=false
done
CHANGES+="]"

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch '{"Changes":'"$CHANGES"'}' \
  --output text > /dev/null
echo "   ACM validation CNAME records added."

echo ""

# --- Done ---
echo "============================================"
echo "  Domain setup complete!"
echo ""
echo "  Certificate: $CERT_ARN"
echo "  CloudFront:  $CF_DOMAIN"
echo "  Domain:      https://$DOMAIN"
echo "  DNS:         Route 53 (zone $HOSTED_ZONE_ID)"
echo ""
echo "  Records created:"
echo "    - A record: $DOMAIN -> $CF_DOMAIN"
echo "    - A record: www.$DOMAIN -> $CF_DOMAIN"
echo "    - TXT record: Google Search Console verification"
echo "    - CNAME records: ACM certificate validation"
echo "============================================"
