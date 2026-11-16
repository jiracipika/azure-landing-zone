# Root module of the Azure Landing Zone. EVERY Azure resource is gated behind
# deploy_enabled (default false): with default variables `terraform plan`
# proposes zero changes outside the placeholder provider configuration.
#
# Wiring order: management groups -> (governance + access control scoped to
# them, observability feeding the diagnostics policy) -> hub network -> spokes
# peered and force-tunnelled to the hub firewall -> budget guardrails on each
# resource group.

locals {
  project = "azure-landing-zone"
  tags    = merge(var.tags, { project = local.project })
}

# --- Tenant plane: management group hierarchy ---------------------------------
module "management_groups" {
  count = var.deploy_enabled ? 1 : 0

  source = "./modules/management_groups"

  subscription_ids = var.subscription_ids
}

# --- Platform management: central workspace -----------------------------------
module "observability" {
  count = var.deploy_enabled ? 1 : 0

  source = "./modules/observability"

  resource_group_name = "rg-alz-management"
  workspace_name      = "log-alz-management"
  location            = var.location
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.tags
}

# --- Governance: custom policies + initiative assigned at the lab root --------
module "governance" {
  count = var.deploy_enabled ? 1 : 0

  source = "./modules/governance"

  root_management_group_id   = one(module.management_groups[*].root_management_group_id)
  location                   = var.location
  allowed_locations          = var.allowed_locations
  allowed_vm_skus            = var.allowed_vm_skus
  required_tag_environment   = var.required_tag_environment
  required_tag_cost_center   = var.required_tag_cost_center
  log_analytics_workspace_id = one(module.observability[*].workspace_id)
}

# --- Connectivity: hub VNet, firewall, VPN gateway, bastion --------------------
module "hub_network" {
  count = var.deploy_enabled ? 1 : 0

  source = "./modules/hub_network"

  resource_group_name        = "rg-alz-connectivity"
  vnet_name                  = "vnet-alz-hub"
  firewall_name              = "afw-alz-hub"
  firewall_policy_name       = "afwp-alz-hub"
  rule_collection_group_name = "arcg-alz-hub"
  vpn_gateway_name           = "vpngw-alz-hub"
  bastion_name               = "bastion-alz-hub"
  location                   = var.location
  address_space              = var.hub_address_space
  spoke_address_spaces       = [for s in var.spokes : s.address_space]
  vpn_gateway_sku            = var.vpn_gateway_sku
  bastion_sku                = var.bastion_sku
  log_analytics_workspace_id = one(module.observability[*].workspace_id)
  tags                       = local.tags
}

# --- Landing zones: dev/prod spokes peered + force-tunnelled to the hub --------
module "spoke_network" {
  for_each = var.deploy_enabled ? var.spokes : {}

  source = "./modules/spoke_network"

  environment             = each.key
  location                = var.location
  address_space           = each.value.address_space
  workload_newbits        = each.value.workload_newbits
  workload_netnum         = each.value.workload_netnum
  hub_vnet_id             = one(module.hub_network[*].vnet_id)
  hub_vnet_name           = one(module.hub_network[*].vnet_name)
  hub_resource_group_name = one(module.hub_network[*].resource_group_name)
  firewall_private_ip     = one(module.hub_network[*].firewall_private_ip)
  tags                    = local.tags
}

# --- Scoped RBAC: corp-only spoke operator --------------------------------------
module "access_control" {
  count = var.deploy_enabled ? 1 : 0

  source = "./modules/access_control"

  root_management_group_id = one(module.management_groups[*].root_management_group_id)
  corp_management_group_id = one(module.management_groups[*].corp_management_group_id)
  principal_id             = var.spoke_operator_principal_id
}

# --- Budget guardrails: one per resource group ----------------------------------
module "budget_management" {
  count = var.deploy_enabled ? 1 : 0

  source = "./modules/budget"

  resource_group_id   = one(module.observability[*].resource_group_id)
  resource_group_name = one(module.observability[*].resource_group_name)
  amount              = var.budget_amount
  alert_emails        = var.budget_alert_emails
}

module "budget_connectivity" {
  count = var.deploy_enabled ? 1 : 0

  source = "./modules/budget"

  resource_group_id   = one(module.hub_network[*].resource_group_id)
  resource_group_name = one(module.hub_network[*].resource_group_name)
  amount              = var.budget_amount
  alert_emails        = var.budget_alert_emails
}
