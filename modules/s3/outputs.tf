output "bucket_name" {
  description = "S3 Bucket name"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "S3 Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "bucket_id" {
  description = "S3 Bucket ID"
  value       = aws_s3_bucket.this.id
}