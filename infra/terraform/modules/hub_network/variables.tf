variable "resource_group_name" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "firewall_name" {
  type = string
}

variable "firewall_policy_name" {
  type = string
}

variable "rule_collection_group_name" {
  type = string
}

variable "vpn_gateway_name" {
  type = string
}

variable "bastion_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  description = "Hub VNet CIDR (/22). Firewall, gateway and bastion subnets are carved from it."
  type        = string
}

variable "spoke_address_spaces" {
  description = "Spoke CIDRs allowed to egress via the firewall (source addresses in the rule base)."
  type        = list(string)
}

variable "vpn_gateway_sku" {
  type = string
}

variable "bastion_sku" {
  type = string
}

variable "log_analytics_workspace_id" {
  description = "Central workspace for firewall diagnostics. Empty default: no diagnostic setting is created."
  type        = string
  default     = ""
}

variable "tags" {
  type = map(string)
}
