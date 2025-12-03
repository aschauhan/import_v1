terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  base_tags = {
    Project = "my-project"
  }
}

module "vpc" {
  source = "../../../modules/vpc"

  cidr_block                           = var.vpc_cidr
  instance_tenancy                     = "default"
  ipv4_ipam_pool_id                    = null
  ipv4_netmask_length                  = null
  ipv6_cidr_block                      = null
  ipv6_ipam_pool_id                    = null
  ipv6_netmask_length                  = null
  ipv6_cidr_block_network_border_group = null
  assign_generated_ipv6_cidr_block     = false
  enable_dns_support                   = true
  enable_dns_hostnames                 = true
  enable_network_address_usage_metrics = false
  environment                          = var.environment
  tags                                 = local.base_tags
}

module "public_subnets" {
  source = "../../../modules/subnets"

  vpc_id             = module.vpc.vpc_id
  subnet_cidrs       = var.public_subnet_cidrs
  availability_zones = var.azs
  map_public_ip      = true
  name_prefix        = "public"
  environment        = var.environment
  tags               = local.base_tags
}

module "private_subnets" {
  source = "../../../modules/subnets"

  vpc_id             = module.vpc.vpc_id
  subnet_cidrs       = var.private_subnet_cidrs
  availability_zones = var.azs
  map_public_ip      = false
  name_prefix        = "private"
  environment        = var.environment
  tags               = local.base_tags
}

module "gateways" {
  source = "../../../modules/gateways"

  vpc_id            = module.vpc.vpc_id
  enable_igw        = true
  nat_subnet_ids    = module.public_subnets.subnet_ids
  nat_gateway_count = length(var.public_subnet_cidrs)
  environment       = var.environment
  tags              = local.base_tags
}

module "route_tables" {
  source = "../../../modules/route-tables"

  vpc_id               = module.vpc.vpc_id
  igw_id               = module.gateways.igw_id
  nat_gateway_ids      = module.gateways.nat_gateway_ids
  public_subnet_ids    = module.public_subnets.subnet_ids
  private_subnet_ids   = module.private_subnets.subnet_ids
  public_subnet_count  = length(var.public_subnet_cidrs)
  private_subnet_count = length(var.private_subnet_cidrs)
  environment          = var.environment
  tags                 = local.base_tags
}

