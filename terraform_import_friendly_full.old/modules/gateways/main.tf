locals {
  tags_final = merge(var.tags, {
    Environment = var.environment
  })
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  count = var.enable_igw ? 1 : 0

  vpc_id = var.vpc_id

  tags = merge(local.tags_final, {
    Name = "${var.name_prefix}-igw"
  })
}

# EIPs for NAT
resource "aws_eip" "nat" {
  count = var.nat_gateway_count

  tags = merge(local.tags_final, {
    Name = "${var.name_prefix}-nat-eip-${count.index}"
  })
}

# NAT Gateways
resource "aws_nat_gateway" "nat_gw" {
  count = var.nat_gateway_count

  subnet_id     = var.nat_subnet_ids[count.index]
  allocation_id = aws_eip.nat[count.index].id

  tags = merge(local.tags_final, {
    Name = "${var.name_prefix}-nat-${count.index}"
  })
}

