# ══════════════════════════════════════════════════════════════════
# EC2 Module — Production (ASG) + R&D (fixed instances)
# ══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────
# PRODUCTION — Launch Templates + Auto Scaling Groups
# ─────────────────────────────────────────────────────────────────
resource "aws_launch_template" "web" {
  count         = var.env == "prod" ? 1 : 0
  name_prefix   = "lt-prod-web-portal-"
  image_id      = var.ami
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_web_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "prod-web-portal", Env = "prod" }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "web" {
  count               = var.env == "prod" ? 1 : 0
  name                = "asg-prod-web-portal"
  min_size            = var.asg_web_min
  max_size            = var.asg_web_max
  desired_capacity    = var.asg_web_desired
  vpc_zone_identifier = var.web_subnet_ids
  target_group_arns   = [var.alb_web_tg_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "prod-web-portal"
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = "prod"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_scale_out" {
  count                  = var.env == "prod" ? 1 : 0
  name                   = "asg-prod-web-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# ── ERP/CRM Launch Template + ASG ────────────────────────────────
resource "aws_launch_template" "erp" {
  count         = var.env == "prod" ? 1 : 0
  name_prefix   = "lt-prod-erp-crm-"
  image_id      = var.ami
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_erp_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "prod-erp-crm", Env = "prod" }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "erp" {
  count               = var.env == "prod" ? 1 : 0
  name                = "asg-prod-erp-crm"
  min_size            = var.asg_erp_min
  max_size            = var.asg_erp_max
  desired_capacity    = var.asg_erp_desired
  vpc_zone_identifier = var.erp_subnet_ids
  target_group_arns   = [var.alb_erp_tg_arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.erp[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "prod-erp-crm"
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = "prod"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "erp_scale_out" {
  count                  = var.env == "prod" ? 1 : 0
  name                   = "asg-prod-erp-scale-out"
  autoscaling_group_name = aws_autoscaling_group.erp[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# ─────────────────────────────────────────────────────────────────
# R&D — Fixed EC2 instances (4 per AZ)
# Không hardcode private IP — để AWS tự cấp phát trong subnet CIDR
# ─────────────────────────────────────────────────────────────────
resource "aws_instance" "rnd_2a" {
  count         = var.env == "rnd" ? var.rnd_instance_count_per_az : 0
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.rnd_subnet_2a_id

  vpc_security_group_ids = [var.sg_rnd_id]

  # Không hardcode private_ip — để AWS tự assign trong subnet 10.1.2.0/24
  tags = {
    Name = "rnd-testing-2a-0${count.index + 1}"
    Env  = "rnd"
    AZ   = "AZ-2a"
  }
}

resource "aws_instance" "rnd_2b" {
  count         = var.env == "rnd" ? var.rnd_instance_count_per_az : 0
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.rnd_subnet_2b_id

  vpc_security_group_ids = [var.sg_rnd_id]

  tags = {
    Name = "rnd-testing-2b-0${count.index + 1}"
    Env  = "rnd"
    AZ   = "AZ-2b"
  }
}