# ── Transit Gateway ───────────────────────────────────────────────
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Central TGW: Prod ↔ R&D ↔ VPN"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = { Name = "tgw-central" }
}

# ── Attachments ───────────────────────────────────────────────────
resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.prod_vpc_id
  subnet_ids         = var.prod_private_subnet_ids

  tags = { Name = "tgw-attach-prod" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "rnd" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.rnd_vpc_id
  subnet_ids         = var.rnd_private_subnet_ids

  tags = { Name = "tgw-attach-rnd" }
}
