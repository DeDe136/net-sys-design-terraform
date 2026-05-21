# ══════════════════════════════════════════════════════════════════
# Transit Gateway module
#
# Creates TGW + Attachments.
# Called AFTER subnets exist (depends_on in root main.tf).
# ══════════════════════════════════════════════════════════════════

resource "aws_ec2_transit_gateway" "this" {
  count = var.create_tgw ? 1 : 0

  description                     = "Central TGW: Prod <-> R&D <-> VPN"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = { Name = "tgw-central" }
}

# ── Attachments — controlled by explicit boolean flags ────────────
# NOTE: Using boolean vars instead of length(subnet_ids) > 0 because
# subnet IDs come from other resources and are unknown at plan time,
# which causes "Invalid count argument" errors in Terraform.
resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  count = var.create_prod_attachment ? 1 : 0

  transit_gateway_id = var.create_tgw ? aws_ec2_transit_gateway.this[0].id : var.existing_tgw_id
  vpc_id             = var.prod_vpc_id
  subnet_ids         = var.prod_private_subnet_ids

  tags = { Name = "tgw-attach-prod" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "rnd" {
  count = var.create_rnd_attachment ? 1 : 0

  transit_gateway_id = var.create_tgw ? aws_ec2_transit_gateway.this[0].id : var.existing_tgw_id
  vpc_id             = var.rnd_vpc_id
  subnet_ids         = var.rnd_private_subnet_ids

  tags = { Name = "tgw-attach-rnd" }
}
