# ── ALB Security Group ────────────────────────────────────────────
resource "aws_security_group" "alb" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sec-alb-${var.env}"
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

  tags = { Name = "sec-alb-${var.env}" }
}

# ── EC2 Web Portal Security Group ─────────────────────────────────
resource "aws_security_group" "ec2_web" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sec-ec2-web-${var.env}"
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

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.prod_vpc_cidr, var.rnd_vpc_cidr]
    description = "ICMP from Production VPC and R&D VPC - allow cross-VPC ping"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sec-ec2-web-${var.env}" }
}

# ── EC2 ERP/CRM Security Group ────────────────────────────────────
resource "aws_security_group" "ec2_erp" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sec-ec2-erp-${var.env}"
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

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.prod_vpc_cidr, var.rnd_vpc_cidr]
    description = "ICMP from Production VPC and R&D VPC - allow cross-VPC ping"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sec-ec2-erp-${var.env}" }
}

# ── RDS Security Group ────────────────────────────────────────────
resource "aws_security_group" "rds" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sec-rds-${var.env}"
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

  tags = { Name = "sec-rds-${var.env}" }
}

# ── Directory Service Security Group ─────────────────────────────
resource "aws_security_group" "ds" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sec-ds-${var.env}"
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

  tags = { Name = "sec-ds-${var.env}" }
}

# ── Bastion Host Security Group (Production) ─────────────────────
# Bastion nằm ở Public Subnet, có 2 phương thức truy cập:
#   1. AWS SSM Session Manager — không cần port 22, truy cập qua HTTPS (443)
#      Yêu cầu: IAM instance profile có AmazonSSMManagedInstanceCore
#      Lệnh: aws ssm start-session --target <instance-id>
#   2. SSH qua Client VPN — port 22 từ VPN CIDR, dùng bastion key pair
#      Yêu cầu: Client VPN connected + ssh-keys/prod/bastion.pem
#
# EC2 Web/ERP chỉ nhận SSH từ Bastion SG → không expose port 22 ra ngoài
resource "aws_security_group" "bastion" {
  count       = var.env == "prod" ? 1 : 0
  name        = "sec-bastion-${var.env}"
  description = "Bastion Host: SSM Session Manager + SSH from Client VPN"
  vpc_id      = var.vpc_id

  # SSH từ Client VPN (phương thức 2 — dự phòng khi SSM không khả dụng)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpn_cidr]
    description = "SSH from Client VPN (fallback - prefer SSM Session Manager)"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.prod_vpc_cidr, var.rnd_vpc_cidr]
    description = "ICMP from Production VPC and R&D VPC - allow cross-VPC ping"
  }

  # Egress mở hoàn toàn — cần để SSM Agent gọi ra SSM endpoints (HTTPS 443)
  # và để Bastion SSH tiếp vào EC2 private subnet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sec-bastion-${var.env}" }
}

# ── R&D EC2 Security Group ────────────────────────────────────────
resource "aws_security_group" "rnd_ec2" {
  count       = var.env == "rnd" ? 1 : 0
  name        = "sec-rnd-ec2"
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

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.rnd_vpc_cidr, var.prod_vpc_cidr]
    description = "ICMP from R&D VPC and Production VPC - allow cross-VPC ping"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sec-rnd-ec2" }
}

# ── EFS Security Group ────────────────────────────────────────────
resource "aws_security_group" "efs" {
  count       = var.env == "rnd" ? 1 : 0
  name        = "sec-efs-rnd"
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

  tags = { Name = "sec-efs-rnd" }
}
