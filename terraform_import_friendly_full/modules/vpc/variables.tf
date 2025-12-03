variable "cidr_block" {
  type        = string
  description = "IPv4 CIDR block for the VPC."
}

variable "instance_tenancy" {
  type        = string
  default     = "default"
  description = "default or dedicated."
}

variable "ipv4_ipam_pool_id" {
  type        = string
  default     = null
}

variable "ipv4_netmask_length" {
  type        = number
  default     = null
}

variable "ipv6_cidr_block" {
  type        = string
  default     = null
}

variable "ipv6_ipam_pool_id" {
  type        = string
  default     = null
}

variable "ipv6_netmask_length" {
  type        = number
  default     = null
}

variable "ipv6_cidr_block_network_border_group" {
  type        = string
  default     = null
}

variable "assign_generated_ipv6_cidr_block" {
  type        = bool
  default     = false
}

variable "enable_dns_support" {
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  type        = bool
  default     = true
}

variable "enable_network_address_usage_metrics" {
  type        = bool
  default     = false
}

variable "environment" {
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

