# Hub-spoke connectivity: hub VNet hosting Azure Firewall, VPN Gateway and
# Bastion. Spokes peer to this hub and route all egress through the firewall
# (see modules/spoke_network). Nothing here is reachable for management except
# Bastion TLS; spokes have no direct Internet ingress path at all.

locals {
  # Subnet plan carved out of the hub /22. Kept explicit so the firewall,
  # gateway and bastion references visibly share one addressing scheme.
  # 10.20.0.0/26  AzureFirewallSubnet (firewall requires /26 minimum)
  # 10.20.0.64/27 GatewaySubnet       (VPN gateway, /27 recommended)
  # 10.20.0.128/26 AzureBastionSubnet (bastion requires /26 minimum)
  firewall_subnet_prefix = cidrsubnet(var.address_space, 4, 0)
  gateway_subnet_prefix  = cidrsubnet(var.address_space, 5, 2)
  bastion_subnet_prefix  = cidrsubnet(var.address_space, 4, 2)
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.firewall_subnet_prefix]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.gateway_subnet_prefix]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # fixed name required by Azure Bastion
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.bastion_subnet_prefix]
}

# --- Public IPs: firewall, bastion and VPN gateway frontends ------------------

resource "azurerm_public_ip" "firewall" {
  name                = "${var.firewall_name}-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.bastion_name}-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "vpn_gateway" {
  name                = "${var.vpn_gateway_name}-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
