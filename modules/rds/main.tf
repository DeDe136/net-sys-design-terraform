# ── DB Subnet Group ───────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "rds-prod-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = { Name = "rds-prod-subnet-group" }
}

# ── RDS MySQL Multi-AZ ────────────────────────────────────────────
resource "aws_db_instance" "primary" {
  identifier             = "rds-prod-primary"
  engine                 = var.engine
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.sg_rds_id]

  multi_az               = true   # Primary + Standby auto-managed by AWS
  publicly_accessible    = false
  deletion_protection    = false
  skip_final_snapshot    = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = {
    Name = "rds-prod-primary"
    Env  = "prod"
  }
}
