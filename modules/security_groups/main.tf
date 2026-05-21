# ── ALB Security Group ────────────────────────────────────────────
resource "aws_security_group" "alb" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sg-alb-${var.env}"
  description = "ALB: HTTP/HTTPS from Internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from Internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from Internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-alb-${var.env}" }
}

# ── EC2 Web Portal Security Group ─────────────────────────────────
resource "aws_security_group" "ec2_web" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sg-ec2-web-${var.env}"
  description = "EC2 Web Portal: traffic from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
    description     = "HTTP from ALB"
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
    description     = "HTTPS from ALB"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion[0].id]
    description     = "SSH from Bastion Host only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-ec2-web-${var.env}" }
}

# ── EC2 ERP/CRM Security Group ────────────────────────────────────
resource "aws_security_group" "ec2_erp" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sg-ec2-erp-${var.env}"
  description = "EC2 ERP/CRM: traffic from Web Portal"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_web[0].id]
    description     = "ERP HTTP from Web"
  }

  ingress {
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_web[0].id]
    description     = "ERP HTTPS from Web"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion[0].id]
    description     = "SSH from Bastion Host only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-ec2-erp-${var.env}" }
}

# ── RDS Security Group ────────────────────────────────────────────
resource "aws_security_group" "rds" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sg-rds-${var.env}"
  description = "RDS MySQL: from ERP and Web"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_erp[0].id]
    description     = "MySQL from ERP"
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_web[0].id]
    description     = "MySQL from Web"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-rds-${var.env}" }
}

# ── Directory Service Security Group ─────────────────────────────
resource "aws_security_group" "ds" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sg-ds-${var.env}"
  description = "Directory Service: LDAP/LDAPS from Web"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 389
    to_port         = 389
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_web[0].id]
    description     = "LDAP from Web"
  }

  ingress {
    from_port       = 636
    to_port         = 636
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_web[0].id]
    description     = "LDAPS from Web"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-ds-${var.env}" }
}

# ── Bastion Host Security Group (Production) ─────────────────────
# Bastion nằm ở Public Subnet, chỉ nhận SSH từ VPN CIDR
# EC2 private (Web/ERP) chỉ nhận SSH từ Bastion SG → không expose port 22 ra ngoài
resource "aws_security_group" "bastion" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sg-bastion-${var.env}"
  description = "Bastion Host: SSH from Client VPN only"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpn_cidr]
    description = "SSH from Client VPN"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-bastion-${var.env}" }
}

# ── R&D EC2 Security Group ────────────────────────────────────────
resource "aws_security_group" "rnd_ec2" {
  count       = var.env == "rnd" ? 1 : 0
  name        = "sg-rnd-ec2"
  description = "R&D EC2: SSH from VPN, all internal"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpn_cidr]
    description = "SSH from Client VPN"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.rnd_vpc_cidr]
    description = "All internal R&D VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-rnd-ec2" }
}

# ── EFS Security Group ────────────────────────────────────────────
resource "aws_security_group" "efs" {
  count       = var.env == "rnd" ? 1 : 0
  name        = "sg-efs-rnd"
  description = "EFS NFS mount from R&D EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.rnd_ec2[0].id]
    description     = "NFS from R&D EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-efs-rnd" }
}
