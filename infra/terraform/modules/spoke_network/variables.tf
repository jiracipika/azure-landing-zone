variable "environment" {
  description = "Spoke instance key (dev, prod) — names and subnets derive from it."
  type        = string
}

variable "location" {
  type = string
}

variable "address_space" {
  description = "Spoke VNet CIDR; must not overlap the hub or the other spokes."
  type        = string
}

variable "workload_newbits" {
  description = "cidrsubnet newbits for the workload subnet carved from address_space."
  type        = number
  default     = 8
}

variable "workload_netnum" {
  description = "cidrsubnet netnum for the workload subnet."
  type        = number
}

variable "hub_vnet_id" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "hub_resource_group_name" {
  type = string
}

variable "firewall_private_ip" {
  description = "Hub Azure Firewall private IP — next hop of the spoke default route."
  type        = string
}

variable "tags" {
  type = map(string)
}
