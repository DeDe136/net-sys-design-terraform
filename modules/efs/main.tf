# ── EFS File System ───────────────────────────────────────────────
resource "aws_efs_file_system" "this" {
  creation_token   = var.name
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name = var.name
    Env  = "rnd"
  }
}

# ── Mount Targets (one per subnet/AZ) ────────────────────────────
resource "aws_efs_mount_target" "this" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.sg_efs_id]
}

# ── EFS Access Point (optional — for app-level isolation) ─────────
resource "aws_efs_access_point" "rnd" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/rnd-data"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = { Name = "${var.name}-ap" }
}
