variable "vpc_id" {
  type        = string
  description = "VPC ID."
}

variable "subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for subnets."
}

variable "availability_zones" {
  type        = list(string)
  description = "AZs corresponding to subnet_cidrs."
}

variable "map_public_ip" {
  type        = bool
  default     = false
}

variable "name_prefix" {
  type        = string
  default     = "subnet"
}

variable "environment" {
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

