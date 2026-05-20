# ══════════════════════════════════════════════════════════════════
# global/providers.tf — AWS Provider Configuration
#
# Module global/ chạy độc lập (cd global && terraform apply),
# nên cần provider block riêng — không kế thừa từ thư mục gốc.
#
# Cách truyền credentials (chọn 1):
#
#   1. Named Profile:
#      terraform apply -var="aws_profile=my-project"
#
#   2. Access Key trực tiếp (dùng -var-file):
#      terraform apply -var="aws_access_key=AKIA..." -var="aws_secret_key=..."
#
#   3. Environment Variables (không cần -var gì thêm):
#      export AWS_ACCESS_KEY_ID="AKIA..."
#      export AWS_SECRET_ACCESS_KEY="..."
#      export AWS_DEFAULT_REGION="us-east-1"
#      terraform apply
#
#   4. Nếu đã có secret.tfvars ở thư mục gốc, truyền thẳng:
#      terraform apply -var-file="../secret.tfvars"
# ══════════════════════════════════════════════════════════════════

provider "aws" {
  region = var.aws_region

  profile    = var.aws_profile != "" ? var.aws_profile : null
  access_key = var.aws_access_key != "" ? var.aws_access_key : null
  secret_key = var.aws_secret_key != "" ? var.aws_secret_key : null

  dynamic "assume_role" {
    for_each = var.aws_role_arn != "" ? [1] : []
    content {
      role_arn     = var.aws_role_arn
      session_name = "terraform-session-global"
    }
  }

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "aws-infrastructure"
      Layer     = "global"
    }
  }
}
