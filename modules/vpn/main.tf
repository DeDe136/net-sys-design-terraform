# ══════════════════════════════════════════════════════════════════
# Client VPN Endpoint
# NOTE: Requires ACM certificates for server & client.
#       Generate self-signed certs with easy-rsa and import to ACM,
#       then set the ARNs via TF_VAR_server_certificate_arn và
#       TF_VAR_client_certificate_arn trước khi terraform apply.
# ══════════════════════════════════════════════════════════════════

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "Client VPN — Remote Staff access"
  server_certificate_arn = var.server_certificate_arn
  client_cidr_block      = var.client_cidr
  split_tunnel           = true   # Chỉ route traffic nội bộ qua VPN

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.client_certificate_arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.vpn.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.vpn.name
  }

  # DNS server trong Production VPC
  dns_servers = ["10.0.0.2"]

  tags = { Name = var.name }
}

# ── CloudWatch Log Group for VPN ─────────────────────────────────
resource "aws_cloudwatch_log_group" "vpn" {
  name              = "/aws/client-vpn/${var.name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "vpn" {
  name           = "connections"
  log_group_name = aws_cloudwatch_log_group.vpn.name
}

# ── Associate VPN to target subnet (prod private 1a) ─────────────
resource "aws_ec2_client_vpn_network_association" "prod_1a" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = var.target_subnet_id
}

# ── Authorization rules ───────────────────────────────────────────
resource "aws_ec2_client_vpn_authorization_rule" "prod" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = "10.0.0.0/16"
  authorize_all_groups   = true
  description            = "Allow VPN clients → Production VPC"
}

resource "aws_ec2_client_vpn_authorization_rule" "rnd" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = "10.1.0.0/16"
  authorize_all_groups   = true
  description            = "Allow VPN clients → R&D VPC (via TGW)"
}

# ── Routes ───────────────────────────────────────────────────────
# Route Prod VPC: đi qua subnet association
resource "aws_ec2_client_vpn_route" "prod" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = "10.0.0.0/16"
  target_vpc_subnet_id   = var.target_subnet_id
  description            = "Route to Production VPC"

  depends_on = [aws_ec2_client_vpn_network_association.prod_1a]
}

# Route R&D VPC: cũng đi qua cùng subnet (prod private 1a có route đến TGW)
resource "aws_ec2_client_vpn_route" "rnd" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = "10.1.0.0/16"
  target_vpc_subnet_id   = var.target_subnet_id
  description            = "Route to R&D VPC via Transit Gateway"

  depends_on = [aws_ec2_client_vpn_network_association.prod_1a]
}