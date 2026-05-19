output "tgw_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.this.id
}

output "tgw_attach_prod_id" {
  description = "TGW Attachment ID for Production VPC"
  value       = aws_ec2_transit_gateway_vpc_attachment.prod.id
}

output "tgw_attach_rnd_id" {
  description = "TGW Attachment ID for R&D VPC"
  value       = aws_ec2_transit_gateway_vpc_attachment.rnd.id
}
