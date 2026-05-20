# ══════════════════════════════════════════════════════════════════
# providers.tf — AWS Provider Configuration
#
# Hỗ trợ 4 phương thức xác thực (chọn 1, uncomment tương ứng):
#
#   1. AWS Profile (~/.aws/credentials)  ← mặc định, không cần CLI
#   2. Access Key / Secret Key trực tiếp
#   3. IAM Role (assume_role)
#   4. Environment Variables (TF_VAR hoặc AWS_*)
#
# Không cần cài AWS CLI — chỉ cần file credentials hoặc biến môi trường.
#
# LƯU Ý: required_version và required_providers được khai báo trong
# versions.tf — không khai báo lại ở đây để tránh trùng lặp.
# ══════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════
# PHƯƠNG THỨC 1: AWS Named Profile (không cần AWS CLI)
# ─────────────────────────────────────────────────────────────────
# Tạo file ~/.aws/credentials với nội dung:
#
#   [my-project]
#   aws_access_key_id     = AKIAIOSFODNN7EXAMPLE
#   aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
#
# Sau đó set biến: export TF_VAR_aws_profile="my-project"
# hoặc chỉnh aws_profile trong secret.tfvars
# ══════════════════════════════════════════════════════════════════
provider "aws" {
  region = var.aws_region

  # ── Phương thức 1: Named Profile ──────────────────────────────
  # Set aws_profile = "my-profile" trong secret.tfvars
  profile = var.aws_profile != "" ? var.aws_profile : null

  # ── Phương thức 2: Access Key trực tiếp ───────────────────────
  # Set aws_access_key + aws_secret_key trong secret.tfvars
  # Terraform bỏ qua nếu để trống (""), profile/env vars được dùng thay thế
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null

  # ── Phương thức 3: Assume IAM Role ────────────────────────────
  # Set aws_role_arn trong secret.tfvars nếu cần
  dynamic "assume_role" {
    for_each = var.aws_role_arn != "" ? [1] : []
    content {
      role_arn     = var.aws_role_arn
      session_name = "terraform-session"
      external_id  = var.aws_role_external_id != "" ? var.aws_role_external_id : null
    }
  }

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "aws-infrastructure"
      Environment = var.aws_profile != "" ? var.aws_profile : "default"
    }
  }
}

# ══════════════════════════════════════════════════════════════════
# PHƯƠNG THỨC 4: Environment Variables (không cần file nào)
# ─────────────────────────────────────────────────────────────────
# Terraform tự động đọc các biến môi trường sau:
#
#   export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
#   export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
#   export AWS_DEFAULT_REGION="us-east-1"
#
# Nếu dùng phương thức này, không cần khai báo gì thêm trong provider.
# Chỉ cần để provider block như trên (profile = null sẽ fallback về env vars).
# ══════════════════════════════════════════════════════════════════
