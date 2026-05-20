#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# scripts/bootstrap_backend.sh
# Tạo S3 bucket và DynamoDB table để lưu Terraform remote state.
# Chạy một lần duy nhất trước khi terraform init.
#
# Cách dùng:
#   chmod +x scripts/bootstrap_backend.sh
#   bash scripts/bootstrap_backend.sh
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="tfstate-aws-infra-${ACCOUNT_ID}"
DYNAMO_TABLE="terraform-state-lock"

echo "==> Account ID: ${ACCOUNT_ID}"
echo "==> Bucket:     ${BUCKET}"
echo "==> Region:     ${REGION}"
echo ""

# ── S3 bucket ─────────────────────────────────────────────────────
if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "[SKIP] Bucket ${BUCKET} already exists"
else
  echo "[CREATE] S3 bucket: ${BUCKET}"
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
fi

# Versioning
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled
echo "[OK] Versioning enabled"

# Block public access
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo "[OK] Public access blocked"

# Server-side encryption
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
    }]
  }'
echo "[OK] SSE-S3 encryption enabled"

# ── DynamoDB table ────────────────────────────────────────────────
if aws dynamodb describe-table --table-name "${DYNAMO_TABLE}" --region "${REGION}" 2>/dev/null; then
  echo "[SKIP] DynamoDB table ${DYNAMO_TABLE} already exists"
else
  echo "[CREATE] DynamoDB table: ${DYNAMO_TABLE}"
  aws dynamodb create-table \
    --table-name "${DYNAMO_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
  echo "[OK] DynamoDB table created"
fi

echo ""
echo "=== Bootstrap hoàn tất ==="
echo "Tiếp theo:"
echo "  1. Mở backend.tf và uncomment block backend"
echo "  2. Thay <account_id> bằng: ${ACCOUNT_ID}"
echo "  3. Chạy: terraform init -reconfigure"
