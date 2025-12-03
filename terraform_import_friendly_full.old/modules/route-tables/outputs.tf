output "public_route_table_ids" {
  value       = aws_route_table.public[*].id
  description = "Public route table IDs."
}

output "private_route_table_ids" {
  value       = aws_route_table.private[*].id
  description = "Private route table IDs."
}

