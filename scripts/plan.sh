#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
# scripts/plan.sh
# Chạy terraform plan, tự động load secret.tfvars nếu tồn tại.
#
# Cách dùng:
#   bash scripts/plan.sh
#
# Yêu cầu: file secret.tfvars ở thư mục gốc (xem secret.tfvars.example)
# ──────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

SECRET_FILE="$ROOT_DIR/secret.tfvars"
VAR_ARGS=""

if [[ -f "$SECRET_FILE" ]]; then
  echo "✓ Đã tìm thấy secret.tfvars"
  VAR_ARGS="-var-file=secret.tfvars"
else
  echo "⚠ Không tìm thấy secret.tfvars — dùng environment variables"
  : "${TF_VAR_rds_password:?'ERROR: rds_password chưa được set (secret.tfvars hoặc TF_VAR_rds_password)'}"
  : "${TF_VAR_ds_directory_password:?'ERROR: ds_directory_password chưa được set'}"
fi

cd "$ROOT_DIR"
terraform fmt -recursive
terraform validate
terraform plan $VAR_ARGS -out=tfplan

echo ""
echo "Plan lưu tại: tfplan"
echo "Để apply: terraform apply tfplan"
