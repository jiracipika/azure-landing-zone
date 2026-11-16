output "root_management_group_id" {
  description = "Id of the lab root management group — the governance baseline assignment target."
  value       = azurerm_management_group.root.id
}

output "management_group_ids" {
  description = "Id of every node in the hierarchy, keyed by node name."
  value       = local.mg_ids
}

output "corp_management_group_id" {
  description = "Id of the corp landing zone — the ONLY scope of the alz-spoke-operator custom role."
  value       = azurerm_management_group.corp.id
}

output "subscription_association_ids" {
  description = "Ids of subscription placement associations (empty unless subscription_ids is set)."
  value       = { for k, v in azurerm_management_group_subscription_association.this : k => v.id }
}
