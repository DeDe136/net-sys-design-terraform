# ══════════════════════════════════════════════════════════════════
# global/versions.tf — Terraform & Provider Version Constraints
#
# Module global/ là một root module RIÊNG BIỆT (có terraform.tfstate
# riêng), nên phải khai báo versions + providers độc lập với
# thư mục gốc.
# ══════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
