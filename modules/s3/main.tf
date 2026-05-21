# ── Lấy ARN của IAM principal đang chạy Terraform ────────────────
data "aws_caller_identity" "current" {}

# ── S3 Bucket ─────────────────────────────────────────────────────
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = {
    Name = var.bucket_name
    Env  = "shared"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

  depends_on = [aws_s3_bucket.this]
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.this]
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [
    aws_s3_bucket_server_side_encryption_configuration.this,
    aws_s3_bucket_public_access_block.this,
  ]
}

# ── Bucket Policy ─────────────────────────────────────────────────
# Dùng 2 statement Allow thay vì 1 statement Deny để tránh self-locking:
#   - Allow toàn bộ s3:* từ VPC Endpoint (traffic hợp lệ)
#   - Allow các action quản lý từ IAM principal chạy Terraform
# Mọi request không khớp 2 điều kiện trên sẽ bị implicit deny bởi AWS IAM
# — hiệu quả bảo mật tương đương Deny nhưng không khóa Terraform.
resource "aws_s3_bucket_policy" "this" {
  count  = length(var.vpc_endpoint_ids) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowViaVpcEndpointsOnly"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:sourceVpce" = var.vpc_endpoint_ids
          }
        }
      },
      {
        Sid    = "AllowTerraformManagement"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action = [
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_versioning.this,
    aws_s3_bucket_server_side_encryption_configuration.this,
    aws_s3_bucket_public_access_block.this,
  ]
}
