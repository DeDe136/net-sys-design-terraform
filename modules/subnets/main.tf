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
}

resource "aws_nat_gateway" "nat_1b" {
  allocation_id = aws_eip.nat_1b.id
  subnet_id     = aws_subnet.public_1b.id
  tags          = { Name = "nat-${var.name_prefix}-1b" }
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

# Private RT AZ-1a → NAT + TGW
resource "aws_route_table" "private_1a" {
  vpc_id = var.vpc_id
  tags   = { Name = "rt-${var.name_prefix}-private-1a" }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1a.id
  }

  route {
    cidr_block         = var.remote_vpc_cidr
    transit_gateway_id = var.tgw_id
  }
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_1a.id
}

# Private RT AZ-1b → NAT + TGW
resource "aws_route_table" "private_1b" {
  vpc_id = var.vpc_id
  tags   = { Name = "rt-${var.name_prefix}-private-1b" }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1b.id
  }

  route {
    cidr_block         = var.remote_vpc_cidr
    transit_gateway_id = var.tgw_id
  }
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private_1b.id
}
