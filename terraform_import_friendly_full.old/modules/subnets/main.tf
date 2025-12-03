locals {
  tags_final = merge(var.tags, {
    Environment = var.environment
  })
}

resource "aws_subnet" "this" {
  for_each = {
    for idx, cidr in var.subnet_cidrs :
    idx => {
      cidr = cidr
      az   = var.availability_zones[idx]
    }
  }

  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = var.map_public_ip

  tags = merge(
    local.tags_final,
    {
      Name = format("%s-%s", var.name_prefix, each.key)
    }
  )
}

