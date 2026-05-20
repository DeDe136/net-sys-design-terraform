# ══════════════════════════════════════════════════════════════════
# versions.tf — Terraform & Provider Version Constraints
#
# File này là nơi DUY NHẤT khai báo required_version và
# required_providers cho root module.
#
# Tách khỏi providers.tf để đúng convention Terraform:
#   versions.tf  → khai báo version constraint (meta)
#   providers.tf → khai báo provider configuration (runtime)
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
