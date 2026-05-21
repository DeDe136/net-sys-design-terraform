output "directory_id" {
  description = "Directory Service ID"
  value       = aws_directory_service_directory.this.id
}

output "directory_dns_ip_addrs" {
  description = "DNS IP addresses of the directory (Primary + Standby)"
  value       = aws_directory_service_directory.this.dns_ip_addresses
}

output "directory_alias" {
  description = "Alias of the directory"
  value       = aws_directory_service_directory.this.alias
}