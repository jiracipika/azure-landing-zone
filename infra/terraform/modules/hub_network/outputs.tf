output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "resource_group_id" {
  value = azurerm_resource_group.this.id
}

output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "firewall_private_ip" {
  description = "Next hop for every spoke default route (UDR 0.0.0.0/0)."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "vpn_gateway_id" {
  value = azurerm_virtual_network_gateway.vpn.id
}

output "bastion_dns_name" {
  value = azurerm_bastion_host.this.dns_name
}
