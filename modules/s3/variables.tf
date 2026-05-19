variable "bucket_name" {
  type        = string
  description = "S3 bucket name"
}

variable "vpc_endpoint_ids" {
  type        = list(string)
  description = "List of VPC Endpoint IDs allowed to access the bucket (from prod and rnd VPCs)"
  default     = []
}