output "efs_id" {
  description = "EFS File System ID"
  value       = aws_efs_file_system.this.id
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = aws_efs_file_system.this.dns_name
}

output "efs_access_point_id" {
  description = "EFS Access Point ID"
  value       = aws_efs_access_point.rnd.id
}
