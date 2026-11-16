# Single assignment of the governance baseline at the LAB ROOT management
# group: every node below (platform, landing zones, corp, online, ...) inherits
# it — the governance-inheritance proof of this repository.
#
# enforce = false is deliberate (audit-first rollout): nothing is denied or
# remediated until the owner flips it after reviewing compliance results.
# The identity block is REQUIRED regardless: the DeployIfNotExists reference
# provisions a remediation identity (granted Contributor on target scopes).
resource "azurerm_management_group_policy_assignment" "governance_baseline" {
  name                 = "alz-governance-baseline"
  display_name         = "ALZ governance baseline"
  description          = "Audit-first rollout: locations, VM SKUs, mandatory tags, VM diagnostics. Inherited by every management group under alz-root."
  management_group_id  = var.root_management_group_id
  policy_definition_id = azurerm_policy_set_definition.governance_baseline.id
  location             = var.location
  enforce              = false

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    allowedLocations       = { value = var.allowed_locations }
    allowedVmSkus          = { value = var.allowed_vm_skus }
    requiredTagEnvironment = { value = var.required_tag_environment }
    requiredTagCostCenter  = { value = var.required_tag_cost_center }
    workspaceResourceId    = { value = var.log_analytics_workspace_id }
  })
}
