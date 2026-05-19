output "rds_endpoint" {
  description = "RDS Primary endpoint (host:port)"
  value       = aws_db_instance.primary.endpoint
}

output "rds_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.primary.id
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.primary.arn
}
