# ══════════════════════════════════════════════════════════════════
# ALB Module — Production only
# ALB chỉ load balance cho EC2 Web Portal.
# EC2 ERP/CRM nhận traffic nội bộ từ Web Portal (không qua ALB).
# ══════════════════════════════════════════════════════════════════

resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  tags = { Name = var.name }
}

# ── Target Group: Web Portal only ────────────────────────────────
resource "aws_lb_target_group" "web" {
  name     = "${var.name}-tg-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  tags = { Name = "${var.name}-tg-web" }
}

# ── Listener HTTP → Web Portal ────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# HTTPS listener — add certificate_arn when ACM cert is ready
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.this.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.certificate_arn
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.web.arn
#   }
# }
