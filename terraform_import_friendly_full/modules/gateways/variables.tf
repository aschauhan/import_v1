variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "enable_igw" {
  type        = bool
  default     = true
}

variable "nat_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Subnets in which to place NAT gateways (usually public subnets)."
}

variable "nat_gateway_count" {
  type        = number
  description = "Number of NAT gateways to create."
}

variable "name_prefix" {
  type        = string
  default     = "gw"
}

variable "environment" {
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

