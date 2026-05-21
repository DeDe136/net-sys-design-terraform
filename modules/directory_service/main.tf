# ══════════════════════════════════════════════════════════════════
# AWS Managed Microsoft AD (Directory Service)
# Production: Multi-AZ — Primary (AZ-1a) + Standby (AZ-1b)
# ══════════════════════════════════════════════════════════════════

resource "aws_directory_service_directory" "this" {
  name       = var.directory_name      # e.g. "corp.example.com"
  short_name = var.directory_short_name # e.g. "CORP"
  password   = var.directory_password
  edition    = var.edition              # "Standard" hoặc "Enterprise"
  type       = "MicrosoftAD"

  vpc_settings {
    vpc_id = var.vpc_id
    # AWS yêu cầu đúng 2 subnet ở 2 AZ khác nhau
    subnet_ids = var.subnet_ids
  }

  tags = {
    Name = var.name
    Env  = "prod"
  }
}

# ── Security Group rule bổ sung: cho phép DS → EC2 (nếu cần Kerberos) ──
# Các rule chính đã được khai báo trong security_groups module