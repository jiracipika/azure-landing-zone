# Landing-zone spoke (instantiated per environment: dev, prod).
#
# Invariants (asserted by tests/test_landing_zone.py):
# - NO inbound allow rule exists anywhere in the spoke: the NSG carries a
#   single explicit Deny-All-Inbound rule, so workload ingress must come
#   through a vetted pattern (private endpoint, peered hub path) — never a
#   public listener;
# - the ONLY egress path is the hub firewall: a route table overrides the
#   default system route with 0.0.0.0/0 -> firewall private IP;
# - peering to the hub allows gateway transit (hub side) and remote gateway
#   use (spoke side) so spokes can reach on-premises via the VPN gateway.

locals {
  workload_subnet_prefix = cidrsubnet(var.address_space, var.workload_newbits, var.workload_netnum)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-alz-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-alz-${var.environment}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload-${var.environment}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.workload_subnet_prefix]

  # No implicit outbound IPs: egress is the hub firewall via the UDR below.
  default_outbound_access_enabled = false
}

# --- Default-deny NSG ---------------------------------------------------------

resource "azurerm_network_security_group" "this" {
  name                = "nsg-alz-${var.environment}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = var.tags
}

# Single explicit deny: inbound traffic is refused even before platform
# defaults are consulted; ingress patterns are added per-workload later ONLY
# with an accompanying governance review (see docs/SECURITY.md).
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# --- Forced tunneling through the hub firewall --------------------------------

resource "azurerm_route_table" "this" {
  name                = "rt-alz-${var.environment}"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = var.tags

  route = [
    {
      name                   = "default-via-firewall"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.firewall_private_ip
    }
  ]
}

resource "azurerm_subnet_route_table_association" "this" {
  subnet_id      = azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.this.id
}

# --- Bidirectional peering with the hub ---------------------------------------

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.environment}-to-hub"
  resource_group_name       = azurerm_resource_group.this.name
  virtual_network_name      = azurerm_virtual_network.this.name
  remote_virtual_network_id = var.hub_vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-${var.environment}"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.this.id

  allow_virtual_network_access = true
  allow_gateway_transit        = true
}
