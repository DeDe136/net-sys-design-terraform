output "vpn_endpoint_id" {
  description = "Client VPN Endpoint ID"
  value       = aws_ec2_client_vpn_endpoint.this.id
}

output "vpn_endpoint_dns" {
  description = "Client VPN DNS name (for .ovpn config)"
  value       = aws_ec2_client_vpn_endpoint.this.dns_name
}
