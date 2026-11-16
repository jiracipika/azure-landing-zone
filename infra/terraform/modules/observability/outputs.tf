output "workspace_id" {
  description = "ARM id — consumed by the VM-diagnostics DeployIfNotExists policy and firewall diagnostics."
  value       = azurerm_log_analytics_workspace.this.id
}

output "resource_group_id" {
  value = azurerm_resource_group.this.id
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}
