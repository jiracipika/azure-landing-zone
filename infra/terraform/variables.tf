variable "deploy_enabled" {
  description = "Approval guard. When false, `terraform plan` shows zero Azure resources."
  type        = bool
  default     = false
}

variable "location" {
  description = "Primary portfolio region (must appear in allowed_locations)."
  type        = string
  default     = "canadacentral"
}

variable "azure_subscription_id" {
  description = "Target subscription. Placeholder default passes offline validation only."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "azure_tenant_id" {
  description = "Tenant that owns the management group hierarchy. Placeholder default passes offline validation only."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "allowed_locations" {
  description = "Locations permitted by the alz-allowed-locations policy (inherited by every management group under the root)."
  type        = list(string)
  default     = ["canadacentral", "canadaeast", "global"]
}

variable "allowed_vm_skus" {
  description = "VM SKUs permitted by the alz-allowed-vm-skus policy (low-cost B/D-series lab floor)."
  type        = list(string)
  default     = ["Standard_B1s", "Standard_B2s", "Standard_B2ms", "Standard_D2s_v5"]
}

variable "required_tag_environment" {
  description = "Tag name required on all resources by the governance initiative."
  type        = string
  default     = "environment"
}

variable "required_tag_cost_center" {
  description = "Second mandatory governance tag."
  type        = string
  default     = "costCenter"
}

variable "subscription_ids" {
  description = "Placement of EXISTING subscriptions into the hierarchy, e.g. {connectivity = \"<guid>\"}. Empty default: nothing is moved."
  type        = map(string)
  default     = {}
}

variable "spokes" {
  description = "Spoke environments (dev/prod) carved per landing zone; each peers to the hub and routes egress via the firewall."
  type = map(object({
    address_space    = optional(string)
    workload_newbits = optional(number, 8)
    workload_netnum  = number
  }))
  default = {
    dev  = { workload_netnum = 1 }
    prod = { workload_netnum = 1 }
  }
}

variable "hub_address_space" {
  description = "Hub VNet CIDR. Firewall/Gateway/Bastion subnets are carved from it in modules/hub_network."
  type        = string
  default     = "10.20.0.0/22"
}

variable "vpn_gateway_sku" {
  description = "Route-based VPN gateway SKU. VpnGw1 is the cheapest standing option; see docs/COSTS.md."
  type        = string
  default     = "VpnGw1"

  validation {
    condition     = contains(["VpnGw1", "VpnGw2", "VpnGw3"], var.vpn_gateway_sku)
    error_message = "vpn_gateway_sku must be VpnGw1, VpnGw2 or VpnGw3."
  }
}

variable "bastion_sku" {
  description = "Bastion SKU. Basic is the cheapest standing option (see docs/COSTS.md)."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.bastion_sku)
    error_message = "bastion_sku must be Basic or Standard."
  }
}

variable "budget_amount" {
  description = "Monthly spend target (CAD) per resource group. Alerts only — budgets do not stop billing."
  type        = number
  default     = 10

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be positive."
  }
}

variable "budget_alert_emails" {
  description = "Email recipients for budget alerts. Empty default keeps the offline scaffold inert."
  type        = list(string)
  default     = []
}

variable "log_analytics_retention_days" {
  description = "Workspace data retention (30 days is the cheapest interactive band)."
  type        = number
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "log_analytics_retention_days must be between 30 and 730."
  }
}

variable "spoke_operator_principal_id" {
  description = "Object ID granted the scoped alz-spoke-operator role. REQUIRED before enabling deploy_enabled; empty default keeps the offline scaffold inert."
  type        = string
  default     = ""
}

variable "tags" {
  type = map(string)
  default = {
    environment = "portfolio-lab"
    managed_by  = "terraform"
  }
}
