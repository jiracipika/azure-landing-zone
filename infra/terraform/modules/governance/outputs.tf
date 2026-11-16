output "governance_initiative_id" {
  description = "Resource id of the alz-governance-baseline policy set definition."
  value       = azurerm_policy_set_definition.governance_baseline.id
}

output "governance_assignment_id" {
  description = "Resource id of the management-group policy assignment (inherited by all descendants of alz-root)."
  value       = azurerm_management_group_policy_assignment.governance_baseline.id
}

output "policy_definition_ids" {
  description = "Resource ids of every custom policy definition in the baseline."
  value = {
    allowed_locations     = azurerm_policy_definition.allowed_locations.id
    allowed_vm_skus       = azurerm_policy_definition.allowed_vm_skus.id
    require_tag           = azurerm_policy_definition.require_tag.id
    deploy_vm_diagnostics = azurerm_policy_definition.deploy_vm_diagnostics.id
  }
}
