# ── Public Subnets ────────────────────────────────────────────────
resource "aws_subnet" "public_1a" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_1a_cidr
  availability_zone       = var.az_1a
  map_public_ip_on_launch = true
  tags = { Name = "${var.name_prefix}-public-1a" }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_1b_cidr
  availability_zone       = var.az_1b
  map_public_ip_on_launch = true
  tags = { Name = "${var.name_prefix}-public-1b" }
}

# ── Private Subnets ───────────────────────────────────────────────
resource "aws_subnet" "private_1a" {
  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnet_1a_cidr
  availability_zone = var.az_1a
  tags = { Name = "${var.name_prefix}-private-1a" }
}

resource "aws_subnet" "private_1b" {
  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnet_1b_cidr
  availability_zone = var.az_1b
  tags = { Name = "${var.name_prefix}-private-1b" }
}

# ── DB Subnets (Production only) ──────────────────────────────────
resource "aws_subnet" "db_1a" {
  count             = var.db_subnet_1a_cidr != null ? 1 : 0
  vpc_id            = var.vpc_id
  cidr_block        = var.db_subnet_1a_cidr
  availability_zone = var.az_1a
  tags = { Name = "${var.name_prefix}-db-1a" }
}

resource "aws_subnet" "db_1b" {
  count             = var.db_subnet_1b_cidr != null ? 1 : 0
  vpc_id            = var.vpc_id
  cidr_block        = var.db_subnet_1b_cidr
  availability_zone = var.az_1b
  tags = { Name = "${var.name_prefix}-db-1b" }
}

# ── Dedicated TGW Subnets (/28) ───────────────────────────────────
# Tách riêng khỏi EC2 private subnet theo AWS best practice.
# TGW ENI sẽ được đặt vào đây thay vì dùng chung private subnet.
# /28 (16 IPs) đủ cho TGW ENI per AZ.
resource "aws_subnet" "tgw_1a" {
  count             = var.tgw_subnet_1a_cidr != null ? 1 : 0
  vpc_id            = var.vpc_id
  cidr_block        = var.tgw_subnet_1a_cidr
  availability_zone = var.az_1a
  tags = { Name = "${var.name_prefix}-tgw-1a" }
}

resource "aws_subnet" "tgw_1b" {
  count             = var.tgw_subnet_1b_cidr != null ? 1 : 0
  vpc_id            = var.vpc_id
  cidr_block        = var.tgw_subnet_1b_cidr
  availability_zone = var.az_1b
  tags = { Name = "${var.name_prefix}-tgw-1b" }
}

# ── Elastic IPs for NAT ───────────────────────────────────────────
resource "aws_eip" "nat_1a" {
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-eip-nat-1a" }
}

resource "aws_eip" "nat_1b" {
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-eip-nat-1b" }
}

# ── NAT Gateways ──────────────────────────────────────────────────
resource "aws_nat_gateway" "nat_1a" {
  allocation_id = aws_eip.nat_1a.id
  subnet_id     = aws_subnet.public_1a.id
  tags          = { Name = "nat-${var.name_prefix}-1a" }
  depends_on    = [aws_eip.nat_1a]
}

resource "aws_nat_gateway" "nat_1b" {
  allocation_id = aws_eip.nat_1b.id
  subnet_id     = aws_subnet.public_1b.id
  tags          = { Name = "nat-${var.name_prefix}-1b" }
  depends_on    = [aws_eip.nat_1b]
}

# ── Route Tables ─────────────────────────────────────────────────
# Public RT → IGW
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  tags   = { Name = "rt-${var.name_prefix}-public" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

# Private RT AZ-1a → NAT only
# Route TGW KHÔNG đặt inline ở đây — tạo riêng bằng aws_route trong root
# main.tf SAU KHI TGW attachment đã hoàn tất (tránh circular dependency
# subnets ↔ tgw_attachments và lỗi AWS API validate attachment chưa tồn tại).
resource "aws_route_table" "private_1a" {
  vpc_id = var.vpc_id
  tags   = { Name = "rt-${var.name_prefix}-private-1a" }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1a.id
  }
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_1a.id
}

# Private RT AZ-1b → NAT only
resource "aws_route_table" "private_1b" {
  vpc_id = var.vpc_id
  tags   = { Name = "rt-${var.name_prefix}-private-1b" }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1b.id
  }
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private_1b.id
}

# ── TGW Routes — controlled bằng enable_tgw_routes flag ──────────
# Tạo SAU KHI TGW attachments đã hoàn tất (lần apply thứ 2).
# Không còn phụ thuộc vào tgw_attachment_ids từ module tgw_attachments
# → không còn circular dependency.
resource "aws_route" "private_1a_tgw" {
  count                  = var.enable_tgw_routes ? 1 : 0
  route_table_id         = aws_route_table.private_1a.id
  destination_cidr_block = var.remote_vpc_cidr
  transit_gateway_id     = var.tgw_id
  depends_on             = [aws_route_table.private_1a]
}

resource "aws_route" "private_1b_tgw" {
  count                  = var.enable_tgw_routes ? 1 : 0
  route_table_id         = aws_route_table.private_1b.id
  destination_cidr_block = var.remote_vpc_cidr
  transit_gateway_id     = var.tgw_id
  depends_on             = [aws_route_table.private_1b]
}

# ── TGW Subnet Route Table ────────────────────────────────────────
# Dedicated RT cho TGW subnets — không cần route ra ngoài,
# chỉ cần local VPC route (tự động có sẵn trong AWS).
resource "aws_route_table" "tgw" {
  count  = (var.tgw_subnet_1a_cidr != null && var.tgw_subnet_1b_cidr != null) ? 1 : 0
  vpc_id = var.vpc_id
  tags   = { Name = "rt-${var.name_prefix}-tgw" }
  # Không có default route ra ngoài — TGW subnet isolated
}

resource "aws_route_table_association" "tgw_1a" {
  count          = length(aws_subnet.tgw_1a)
  subnet_id      = aws_subnet.tgw_1a[0].id
  route_table_id = aws_route_table.tgw[0].id
}

resource "aws_route_table_association" "tgw_1b" {
  count          = length(aws_subnet.tgw_1b)
  subnet_id      = aws_subnet.tgw_1b[0].id
  route_table_id = aws_route_table.tgw[0].id
}

# ── DB Route Table (Production only) ─────────────────────────────
# DB subnets chỉ cần local route — không ra NAT / Internet.
# Local route (10.0.0.0/16 → local) tự động có sẵn trong mọi RT của AWS.
resource "aws_route_table" "db" {
  count  = (var.db_subnet_1a_cidr != null && var.db_subnet_1b_cidr != null) ? 1 : 0
  vpc_id = var.vpc_id
  tags   = { Name = "rt-${var.name_prefix}-db" }
}

resource "aws_route_table_association" "db_1a" {
  count          = (var.db_subnet_1a_cidr != null && var.db_subnet_1b_cidr != null) ? 1 : 0
  subnet_id      = aws_subnet.db_1a[0].id
  route_table_id = aws_route_table.db[0].id
}

resource "aws_route_table_association" "db_1b" {
  count          = (var.db_subnet_1a_cidr != null && var.db_subnet_1b_cidr != null) ? 1 : 0
  subnet_id      = aws_subnet.db_1b[0].id
  route_table_id = aws_route_table.db[0].id
}
