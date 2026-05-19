output "prod_vpc_id"    { value = module.prod_vpc.vpc_id }
output "rnd_vpc_id"     { value = module.rnd_vpc.vpc_id }
output "prod_alb_dns"   { value = module.prod_alb.alb_dns_name }
output "rds_endpoint"   { value = module.prod_rds.rds_endpoint }
output "efs_id"         { value = module.rnd_efs.efs_id }
output "tgw_id"         { value = module.transit_gateway.tgw_id }
output "s3_bucket_name" { value = module.s3.bucket_name }
