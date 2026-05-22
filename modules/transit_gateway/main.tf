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

# ── Static route: VPN CIDR → Prod VPC attachment ─────────────────
# FIX: Client VPN associate vào Prod private subnet, không attach trực tiếp
# vào TGW. TGW default route table chỉ propagate VPC CIDRs (10.0/16, 10.1/16)
# — không tự biết 172.16.0.0/22 ở đâu.
#
# Cần static route: 172.16.0.0/22 → Prod attachment
# Khi R&D EC2 reply về VPN client (172.16.x.x):
#   R&D subnet RT → TGW (đã có route nhờ fix subnets)
#   TGW RT → Prod attachment (route này) → Client VPN endpoint → VPN client ✅
#
# Guard bằng enable_tgw_routes — cùng flag với cross-VPC routes,
# đảm bảo attachment đã available trước khi tạo route.
# ── Lookup TGW default route table (không có attribute trực tiếp) ─
# aws_ec2_transit_gateway không export default_route_table_id,
# phải dùng data source aws_ec2_transit_gateway_route_table để tìm.
data "aws_ec2_transit_gateway_route_table" "default" {
  count = (var.enable_tgw_routes && var.vpn_cidr != null && var.create_prod_attachment) ? 1 : 0

  filter {
    name   = "transit-gateway-id"
    values = [var.create_tgw ? aws_ec2_transit_gateway.this[0].id : var.existing_tgw_id]
  }
  filter {
    name   = "default-association-route-table"
    values = ["true"]
  }
}

resource "aws_ec2_transit_gateway_route" "vpn_to_prod" {
  count = (var.enable_tgw_routes && var.vpn_cidr != null && var.create_prod_attachment) ? 1 : 0

  destination_cidr_block         = var.vpn_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod[0].id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.default[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.prod]
}
