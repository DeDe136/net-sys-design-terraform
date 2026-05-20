output "public_subnet_1a_id"  { value = aws_subnet.public_1a.id }
output "public_subnet_1b_id"  { value = aws_subnet.public_1b.id }
output "private_subnet_1a_id" { value = aws_subnet.private_1a.id }
output "private_subnet_1b_id" { value = aws_subnet.private_1b.id }
output "db_subnet_1a_id"      { value = length(aws_subnet.db_1a) > 0 ? aws_subnet.db_1a[0].id : null }
output "db_subnet_1b_id"      { value = length(aws_subnet.db_1b) > 0 ? aws_subnet.db_1b[0].id : null }

# Dedicated TGW subnet IDs — truyền vào module tgw_attachments (Phase 4)
output "tgw_subnet_1a_id"     { value = length(aws_subnet.tgw_1a) > 0 ? aws_subnet.tgw_1a[0].id : null }
output "tgw_subnet_1b_id"     { value = length(aws_subnet.tgw_1b) > 0 ? aws_subnet.tgw_1b[0].id : null }

output "private_rt_1a_id"     { value = aws_route_table.private_1a.id }
output "private_rt_1b_id"     { value = aws_route_table.private_1b.id }
output "public_rt_id"         { value = aws_route_table.public.id }
output "db_rt_id"             { value = length(aws_route_table.db) > 0 ? aws_route_table.db[0].id : null }
output "nat_1a_id"            { value = aws_nat_gateway.nat_1a.id }
output "nat_1b_id"            { value = aws_nat_gateway.nat_1b.id }
