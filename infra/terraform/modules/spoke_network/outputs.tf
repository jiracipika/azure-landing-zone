output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "workload_subnet_id" {
  value = azurerm_subnet.workload.id
}

output "workload_subnet_prefix" {
  value = local.workload_subnet_prefix
}

output "resource_group_id" {
  value = azurerm_resource_group.this.id
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}
