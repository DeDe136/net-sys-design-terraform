# ══════════════════════════════════════════════════════════════════
# EC2 Module — Production (ASG) + R&D (fixed instances)
#
# Traffic flow:
#   Internet → ALB → EC2 Web Portal (via NAT cho package updates)
#   EC2 Web Portal → EC2 ERP/CRM (internal, port 8080/8443)
#   EC2 R&D → Internet via NAT Gateway (package updates only, no ALB)
# ══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────
# PRODUCTION — Bastion Host (HA: 1 instance mỗi AZ)
#
# Vị trí: Public Subnet (AZ-1a + AZ-1b) — Production VPC
# Luồng SSH: Remote Staff → Client VPN → Bastion → EC2 Private Subnet
#
# Bastion KHÔNG gắn ALB. Staff SSH vào Bastion trước (port 22),
# sau đó jump tiếp vào Web Portal / ERP/CRM qua private IP.
# ─────────────────────────────────────────────────────────────────
resource "aws_instance" "bastion_1a" {
  count         = var.env == "prod" ? 1 : 0
  ami           = var.ami
  instance_type = var.bastion_instance_type

  subnet_id                   = var.bastion_subnet_1a_id
  vpc_security_group_ids      = [var.sg_bastion_id]
  associate_public_ip_address = false  # Staff reach qua VPN private IP, không cần Public IP
  key_name                    = var.key_name != "" ? var.key_name : null
  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    yum update -y
    # Hardening cơ bản: chỉ cho phép SSH, disable password auth
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
  USERDATA
  )

  tags = {
    Name = "prod-bastion-1a"
    Env  = "prod"
    Role = "bastion"
    AZ   = "AZ-1a"
  }
}

resource "aws_instance" "bastion_1b" {
  count         = var.env == "prod" ? 1 : 0
  ami           = var.ami
  instance_type = var.bastion_instance_type

  subnet_id                   = var.bastion_subnet_1b_id
  vpc_security_group_ids      = [var.sg_bastion_id]
  associate_public_ip_address = false  # Staff reach qua VPN private IP, không cần Public IP
  key_name                    = var.key_name != "" ? var.key_name : null
  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    yum update -y
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
  USERDATA
  )

  tags = {
    Name = "prod-bastion-1b"
    Env  = "prod"
    Role = "bastion"
    AZ   = "AZ-1b"
  }
}

# ─────────────────────────────────────────────────────────────────
# PRODUCTION — Launch Templates + Auto Scaling Groups
# ─────────────────────────────────────────────────────────────────

# ── Web Portal (ALB target) ───────────────────────────────────────
resource "aws_launch_template" "web" {
  count         = var.env == "prod" ? 1 : 0
  name_prefix   = "lt-prod-web-portal-"
  image_id      = var.web_portal_ami_id != "" ? var.web_portal_ami_id : var.ami
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_web_id]
  }

  # IAM instance profile — SSM Session Manager + S3 access (tạo trong global/iam.tf)
  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile != "" ? [1] : []
    content {
      name = var.iam_instance_profile
    }
  }

  key_name = var.key_name != "" ? var.key_name : null

  # User data: Start Nginx service (if using custom AMI, Nginx already installed)
  #            If using base image, this provides fallback initialization
  user_data = base64encode(var.web_portal_ami_id != "" ? 
    # Custom AMI path: Nginx already installed, just ensure service is running
    <<-USERDATA
#!/bin/bash
set -euo pipefail
echo "[$(date)] Starting Nginx service..."
systemctl start nginx
systemctl enable nginx
echo "[$(date)] ✓ Nginx service started"
    USERDATA
    :
    # Base image fallback: Install Nginx if needed
    <<-USERDATA
#!/bin/bash
set -euo pipefail
echo "[$(date)] Updating system..."
yum update -y

echo "[$(date)] Installing Nginx..."
yum install -y nginx

echo "[$(date)] Creating web content..."
mkdir -p /var/www/html
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Web Portal - AWS Production</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
    .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    h1 { color: #FF9900; }
    .info { background: #f0f0f0; padding: 15px; border-left: 4px solid #FF9900; margin: 10px 0; }
    .label { font-weight: bold; color: #333; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 Nginx Web Server - Production</h1>
    <div class="info">
      <p class="label">Status:</p> ✅ Active and Running
    </div>
    <div class="info">
      <p class="label">Environment:</p> Amazon Linux 2 - EC2 Portal
    </div>
    <div class="info">
      <p class="label">Health Check:</p> GET /health (Port 80)
    </div>
  </div>
</body>
</html>
EOF

echo "[$(date)] Configuring Nginx..."
cat > /etc/nginx/conf.d/web-portal.conf <<'EOF'
server {
  listen 80 default_server;
  server_name _;
  root /var/www/html;
  
  location /health {
    access_log off;
    return 200 "OK\n";
    add_header Content-Type text/plain;
  }
  
  location / {
    index index.html;
    try_files $uri $uri/ =404;
  }
}
EOF

echo "[$(date)] Starting Nginx..."
nginx -t && systemctl start nginx && systemctl enable nginx
echo "[$(date)] ✓ Nginx started successfully"
    USERDATA
  )

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

  # ALB chỉ gắn với Web Portal
  target_group_arns        = [var.alb_web_tg_arn]
  health_check_type        = "ELB"
  # Grace period: 180s for custom AMI (Nginx already running), 600s for base image with user_data
  health_check_grace_period = var.web_portal_ami_id != "" ? 180 : 600

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

resource "aws_autoscaling_policy" "web_cpu" {
  count                  = var.env == "prod" ? 1 : 0
  name                   = "asg-prod-web-cpu"
  autoscaling_group_name = aws_autoscaling_group.web[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# ── ERP/CRM (KHÔNG gắn ALB — nhận traffic nội bộ từ Web Portal) ──
resource "aws_launch_template" "erp" {
  count         = var.env == "prod" ? 1 : 0
  name_prefix   = "lt-prod-erp-crm-"
  image_id      = var.ami
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.sg_erp_id]
  }

  # IAM instance profile — SSM Session Manager + S3 access (tạo trong global/iam.tf)
  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile != "" ? [1] : []
    content {
      name = var.iam_instance_profile
    }
  }

  key_name = var.key_name != "" ? var.key_name : null

  # User data: cập nhật gói qua NAT Gateway
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    yum update -y
    # Traffic ra internet đi qua NAT Gateway (route table private subnet)
  USERDATA
  )

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

  # KHÔNG gắn target_group_arns — ERP/CRM không được ALB load balance trực tiếp
  # Web Portal sẽ forward request nội bộ đến ERP/CRM qua port 8080/8443
  health_check_type        = "EC2"
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

resource "aws_autoscaling_policy" "erp_cpu" {
  count                  = var.env == "prod" ? 1 : 0
  name                   = "asg-prod-erp-cpu"
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
# R&D — Fixed EC2 instances (rnd_instance_count_per_az per AZ)
# Không gắn ALB. Cập nhật gói từ internet qua NAT Gateway.
# ─────────────────────────────────────────────────────────────────
resource "aws_instance" "rnd_2a" {
  count         = var.env == "rnd" ? var.rnd_instance_count_per_az : 0
  ami           = var.ami
  instance_type = var.instance_type

  # private subnet → traffic ra internet đi qua NAT Gateway (rt-rnd-private-2a)
  subnet_id              = var.rnd_subnet_2a_id
  vpc_security_group_ids = [var.sg_rnd_id]
  key_name               = var.key_name != "" ? var.key_name : null
  iam_instance_profile   = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  # User data: cập nhật gói cần thiết qua NAT Gateway
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    # Internet access via NAT Gateway (route: 0.0.0.0/0 → nat-rnd-2a)
    yum update -y
    # Cài thêm tool R&D nếu cần
  USERDATA
  )

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

  # private subnet → traffic ra internet đi qua NAT Gateway (rt-rnd-private-2b)
  subnet_id              = var.rnd_subnet_2b_id
  vpc_security_group_ids = [var.sg_rnd_id]
  key_name               = var.key_name != "" ? var.key_name : null
  iam_instance_profile   = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  # User data: cập nhật gói cần thiết qua NAT Gateway
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    # Internet access via NAT Gateway (route: 0.0.0.0/0 → nat-rnd-2b)
    yum update -y
    # Cài thêm tool R&D nếu cần
  USERDATA
  )

  tags = {
    Name = "rnd-testing-2b-0${count.index + 1}"
    Env  = "rnd"
    AZ   = "AZ-2b"
  }
}
