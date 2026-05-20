# ──────────────────────────────────────────────────────────────────
# backend.tf  —  Remote state: S3 + DynamoDB locking
#
# Bước 1: Chạy script bootstrap để tạo bucket và DynamoDB table:
#   bash scripts/bootstrap_backend.sh
#
# Bước 2: Uncomment block backend bên dưới và thay <account_id>
#
# Bước 3: Re-init để migrate state:
#   terraform init -reconfigure
# ──────────────────────────────────────────────────────────────────

# terraform {
#   backend "s3" {
#     bucket         = "tfstate-aws-infra-<account_id>"
#     key            = "aws-infra/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
