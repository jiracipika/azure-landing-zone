# Route-based VPN gateway for site-to-site / point-to-site connectivity from
# the on-premises or lab edge. STANDING COST (~$31/mo for VpnGw1 + public IP,
# see docs/COSTS.md) — this is why it stays behind deploy_enabled.
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = var.vpn_gateway_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gateway_sku
  tags                = var.tags

  ip_configuration {
    name                 = "gwconf"
    public_ip_address_id = azurerm_public_ip.vpn_gateway.id
    subnet_id            = azurerm_subnet.gateway.id
  }
}

# Bastion: the ONLY management entry to hub and spokes (TLS in the browser,
# no public SSH/RDP anywhere — asserted by tests).
resource "azurerm_bastion_host" "this" {
  name                = var.bastion_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  sku                 = var.bastion_sku
  tags                = var.tags

  ip_configuration {
    name                 = "bastionconf"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
