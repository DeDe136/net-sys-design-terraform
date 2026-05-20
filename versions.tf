# ──────────────────────────────────────────────────────────────────
# versions.tf  —  Terraform & provider version constraints
# Provider AWS được cấu hình trong providers.tf (hỗ trợ nhiều
# phương thức xác thực: profile, access key, assume role, env vars)
# ──────────────────────────────────────────────────────────────────
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
