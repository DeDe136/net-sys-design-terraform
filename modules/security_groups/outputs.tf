output "sg_alb_id"     { value = length(aws_security_group.alb) > 0 ? aws_security_group.alb[0].id : null }
output "sg_ec2_web_id" { value = length(aws_security_group.ec2_web) > 0 ? aws_security_group.ec2_web[0].id : null }
output "sg_ec2_erp_id" { value = length(aws_security_group.ec2_erp) > 0 ? aws_security_group.ec2_erp[0].id : null }
output "sg_rds_id"     { value = length(aws_security_group.rds) > 0 ? aws_security_group.rds[0].id : null }
output "sg_ds_id"      { value = length(aws_security_group.ds) > 0 ? aws_security_group.ds[0].id : null }
output "sg_rnd_ec2_id" { value = length(aws_security_group.rnd_ec2) > 0 ? aws_security_group.rnd_ec2[0].id : null }
output "sg_efs_id"     { value = length(aws_security_group.efs) > 0 ? aws_security_group.efs[0].id : null }
