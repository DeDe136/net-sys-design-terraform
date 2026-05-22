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
# Lưu ý: KHÔNG cần static route 172.16.0.0/22 → Prod attachment ở đây.
# AWS Client VPN NAT source IP thành Prod subnet IP (10.0.x.x) khi forward
# traffic qua subnet association → TGW chỉ thấy traffic 10.0.x.x ↔ 10.1.x.x,
# không thấy 172.16.x.x. TGW default route table với propagation từ 2 VPC
# attachment là đủ để routing hoạt động.
