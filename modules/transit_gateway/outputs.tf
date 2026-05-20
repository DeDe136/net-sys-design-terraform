output "tgw_id" {
  description = "Transit Gateway ID"
  value       = var.create_tgw ? aws_ec2_transit_gateway.this[0].id : var.existing_tgw_id
}

output "tgw_attach_prod_id" {
  description = "TGW Attachment ID for Production VPC"
  value       = length(aws_ec2_transit_gateway_vpc_attachment.prod) > 0 ? aws_ec2_transit_gateway_vpc_attachment.prod[0].id : null
}

output "tgw_attach_rnd_id" {
  description = "TGW Attachment ID for R&D VPC"
  value       = length(aws_ec2_transit_gateway_vpc_attachment.rnd) > 0 ? aws_ec2_transit_gateway_vpc_attachment.rnd[0].id : null
}
