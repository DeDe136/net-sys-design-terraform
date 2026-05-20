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
# FIX: Không đặt route TGW inline trong aws_route_table.
# AWS validate attachment ngay lúc tạo route — nếu attachment chưa có → lỗi.
# Route TGW được tạo riêng bên dưới bằng aws_route với count guard.
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

# ── TGW Routes — tạo SAU KHI attachment đã hoàn tất ─────────────
# count = 0 khi tgw_attachment_ids rỗng (Phase 3, attachment chưa có).
# count = 1 sau Phase 4 khi root module truyền attachment IDs vào.
# Terraform detect thay đổi count và tạo route trong cùng 1 lần apply.
resource "aws_route" "private_1a_tgw" {
  count                  = length(var.tgw_attachment_ids) > 0 ? 1 : 0
  route_table_id         = aws_route_table.private_1a.id
  destination_cidr_block = var.remote_vpc_cidr
  transit_gateway_id     = var.tgw_id
  depends_on             = [aws_route_table.private_1a]
}

resource "aws_route" "private_1b_tgw" {
  count                  = length(var.tgw_attachment_ids) > 0 ? 1 : 0
  route_table_id         = aws_route_table.private_1b.id
  destination_cidr_block = var.remote_vpc_cidr
  transit_gateway_id     = var.tgw_id
  depends_on             = [aws_route_table.private_1b]
}

# ── DB Route Table (Production only) ─────────────────────────────
# DB subnets chỉ cần route nội bộ, KHÔNG ra NAT / Internet
resource "aws_route_table" "db" {
  count  = (var.db_subnet_1a_cidr != null && var.db_subnet_1b_cidr != null) ? 1 : 0
  vpc_id = var.vpc_id
  tags   = { Name = "rt-${var.name_prefix}-db" }
  # Không có default route ra ngoài — DB subnet isolated
}

resource "aws_route_table_association" "db_1a" {
  count          = length(aws_subnet.db_1a)
  subnet_id      = aws_subnet.db_1a[0].id
  route_table_id = aws_route_table.db[0].id
}

resource "aws_route_table_association" "db_1b" {
  count          = length(aws_subnet.db_1b)
  subnet_id      = aws_subnet.db_1b[0].id
  route_table_id = aws_route_table.db[0].id
}