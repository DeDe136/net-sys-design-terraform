# ──────────────────────────────────────────────────────────────────
# global/iam.tf
# IAM roles và policies dùng chung cho toàn bộ hệ thống.
# Deploy một lần, không phụ thuộc môi trường.
#
# Cách dùng (nếu tách global thành root module riêng):
#   cd global && terraform init && terraform apply
# ──────────────────────────────────────────────────────────────────

# ── EC2 Instance Role (SSM + S3 access) ──────────────────────────
resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ec2-instance-role", ManagedBy = "terraform" }
}

# SSM Session Manager — không cần SSH key, truy cập an toàn
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 read/write cho shared bucket
resource "aws_iam_role_policy" "s3_shared" {
  name = "s3-shared-access"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = ["arn:aws:s3:::s3-prod-shared-*", "arn:aws:s3:::s3-prod-shared-*/*"]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}

# ── Ghi chú: VPN CloudWatch Logging ─────────────────────────────
# Client VPN KHÔNG cần IAM Role để ghi logs.
# AWS tự xử lý authentication nội bộ khi bật connection_log_options.
# CloudWatch Log Group và Log Stream được tạo trực tiếp trong
# modules/vpn/main.tf bằng aws_cloudwatch_log_group + aws_cloudwatch_log_stream.
