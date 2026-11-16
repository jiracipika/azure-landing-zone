output "spoke_operator_role_id" {
  description = "Full ARM id of the alz-spoke-operator custom role."
  value       = azurerm_role_definition.spoke_operator.role_definition_resource_id
}

output "assignment_id" {
  description = "Role assignment id (null unless a principal id is provided)."
  value       = length(azurerm_role_assignment.spoke_operator) > 0 ? azurerm_role_assignment.spoke_operator[0].id : null
}
