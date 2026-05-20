# ══════════════════════════════════════════════════════════════════
# Transit Gateway module
#
# Tạo TGW + Attachments trong 1 lần duy nhất.
# Được gọi SAU KHI subnets đã tồn tại (depends_on trong root main.tf).
# ══════════════════════════════════════════════════════════════════

resource "aws_ec2_transit_gateway" "this" {
  count = var.create_tgw ? 1 : 0

  description                     = "Central TGW: Prod ↔ R&D ↔ VPN"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = { Name = "tgw-central" }
}

# ── Attachments — only created when subnet_ids are provided ───────
resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  count = length(var.prod_private_subnet_ids) > 0 ? 1 : 0

  transit_gateway_id = var.create_tgw ? aws_ec2_transit_gateway.this[0].id : var.existing_tgw_id
  vpc_id             = var.prod_vpc_id
  subnet_ids         = var.prod_private_subnet_ids

  tags = { Name = "tgw-attach-prod" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "rnd" {
  count = length(var.rnd_private_subnet_ids) > 0 ? 1 : 0

  transit_gateway_id = var.create_tgw ? aws_ec2_transit_gateway.this[0].id : var.existing_tgw_id
  vpc_id             = var.rnd_vpc_id
  subnet_ids         = var.rnd_private_subnet_ids

  tags = { Name = "tgw-attach-rnd" }
}
