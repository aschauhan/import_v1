output "igw_id" {
  description = "Internet Gateway ID (or null if disabled)."
  value       = length(aws_internet_gateway.igw) > 0 ? aws_internet_gateway.igw[0].id : null
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs."
  value       = aws_nat_gateway.nat_gw[*].id
}

