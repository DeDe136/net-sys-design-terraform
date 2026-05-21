output "bastion_private_ip_1a" {
  description = "Private IP của Bastion Host AZ-1a (SSH vào sau khi kết nối VPN)"
  value       = var.env == "prod" ? aws_instance.bastion_1a[0].private_ip : null
}

output "bastion_private_ip_1b" {
  description = "Private IP của Bastion Host AZ-1b (SSH vào sau khi kết nối VPN)"
  value       = var.env == "prod" ? aws_instance.bastion_1b[0].private_ip : null
}

output "asg_web_name" {
  description = "Auto Scaling Group name for Web Portal"
  value       = var.env == "prod" ? aws_autoscaling_group.web[0].name : null
}

output "asg_erp_name" {
  description = "Auto Scaling Group name for ERP/CRM"
  value       = var.env == "prod" ? aws_autoscaling_group.erp[0].name : null
}

output "rnd_instance_ids_2a" {
  description = "IDs of R&D EC2 instances in AZ-2a"
  value       = var.env == "rnd" ? aws_instance.rnd_2a[*].id : []
}

output "rnd_instance_ids_2b" {
  description = "IDs of R&D EC2 instances in AZ-2b"
  value       = var.env == "rnd" ? aws_instance.rnd_2b[*].id : []
}
