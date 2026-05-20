# ──────────────────────────────────────────────────────────────────
# outputs.tf
# ──────────────────────────────────────────────────────────────────

output "prod_vpc_id" {
  description = "Production VPC ID"
  value       = module.prod_vpc.vpc_id
}
output "rnd_vpc_id" {
  description = "R&D VPC ID"
  value       = module.rnd_vpc.vpc_id
}
output "prod_public_subnet_ids" {
  value = [module.prod_subnets.public_subnet_1a_id, module.prod_subnets.public_subnet_1b_id]
}
output "prod_private_subnet_ids" {
  value = [module.prod_subnets.private_subnet_1a_id, module.prod_subnets.private_subnet_1b_id]
}
output "prod_alb_dns" {
  description = "ALB DNS name — entry point công khai của hệ thống"
  value       = module.prod_alb.alb_dns_name
}
output "prod_alb_arn" {
  value = module.prod_alb.alb_arn
}
output "asg_web_portal_name" {
  value = module.prod_ec2.asg_web_name
}
output "asg_erp_crm_name" {
  value = module.prod_ec2.asg_erp_name
}
output "rnd_instance_ids_2a" {
  value = module.rnd_ec2.rnd_instance_ids_2a
}
output "rnd_instance_ids_2b" {
  value = module.rnd_ec2.rnd_instance_ids_2b
}
output "rds_endpoint" {
  description = "RDS Primary endpoint"
  value       = module.prod_rds.rds_endpoint
}
output "directory_service_id" {
  value = module.prod_directory_service.directory_id
}
output "directory_dns_ips" {
  value = module.prod_directory_service.directory_dns_ip_addrs
}
output "efs_id" {
  value = module.rnd_efs.efs_id
}
output "efs_dns_name" {
  value = module.rnd_efs.efs_dns_name
}
output "tgw_id" {
  description = "Transit Gateway ID"
  value       = module.transit_gateway.tgw_id
}
output "s3_bucket_name" {
  value = module.s3.bucket_name
}
output "s3_bucket_arn" {
  value = module.s3.bucket_arn
}
# ⚠ FIX: Comment out cùng với module "client_vpn" trong main.tf.
# Terraform báo lỗi "Module not found" nếu output tham chiếu module
# đang bị comment. Bỏ comment 2 output bên dưới SAU KHI enable VPN.
#
# output "client_vpn_endpoint_id" {
#   value = module.client_vpn.vpn_endpoint_id
# }
# output "client_vpn_dns" {
#   description = "Client VPN DNS name (dùng để tạo file .ovpn)"
#   value       = module.client_vpn.vpn_endpoint_dns
# }
