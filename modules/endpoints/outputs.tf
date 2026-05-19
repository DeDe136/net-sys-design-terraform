output "endpoint_id" {
  description = "VPC Endpoint ID (used for S3 bucket policy)"
  value       = aws_vpc_endpoint.s3.id
}

output "endpoint_arn" {
  description = "VPC Endpoint ARN"
  value       = aws_vpc_endpoint.s3.arn
}