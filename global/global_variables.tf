# ══════════════════════════════════════════════════════════════════
# global/variables.tf — Input variables cho global module
# ══════════════════════════════════════════════════════════════════

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS credentials profile (~/.aws/credentials). Để trống nếu dùng env vars."
  default     = ""
}

variable "aws_access_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "AWS Access Key ID (phương thức 2)"
}

variable "aws_secret_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "AWS Secret Access Key (phương thức 2)"
}

variable "aws_role_arn" {
  type        = string
  default     = ""
  description = "IAM Role ARN để assume (phương thức 3)"
}
