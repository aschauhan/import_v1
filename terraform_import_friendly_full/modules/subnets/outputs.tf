output "subnet_ids" {
  value       = [for s in aws_subnet.this : s.id]
  description = "Subnet IDs."
}

output "subnet_cidrs" {
  value       = [for s in aws_subnet.this : s.cidr_block]
  description = "Subnet CIDRs."
}

