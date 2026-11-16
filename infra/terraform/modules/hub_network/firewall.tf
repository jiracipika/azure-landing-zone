# Azure Firewall (Standard tier, classic VNet hub — not Virtual WAN) with a
# Firewall Policy holding the egress rule base for all spokes.
#
# Egress invariants (asserted by tests/test_landing_zone.py):
# - spokes may resolve DNS (UDP/53) and browse the web (TCP 80,443) via the
#   firewall ONLY;
# - SSH/RDP egress from spokes to the Internet is explicitly denied;
# - everything not listed falls to the firewall's implicit deny.

resource "azurerm_firewall_policy" "this" {
  name                = var.firewall_policy_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "this" {
  name                = var.firewall_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = var.tags

  ip_configuration {
    name                 = "fwconf"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = var.rule_collection_group_name
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  network_rule_collection {
    name     = "allow-spoke-egress"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP"]
      source_addresses      = var.spoke_address_spaces
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-web"
      protocols             = ["TCP"]
      source_addresses      = var.spoke_address_spaces
      destination_addresses = ["*"]
      destination_ports     = ["80", "443"]
    }
  }

  network_rule_collection {
    name     = "deny-spoke-mgmt-egress"
    priority = 200
    action   = "Deny"

    rule {
      name                  = "deny-ssh-rdp-egress"
      protocols             = ["TCP"]
      source_addresses      = var.spoke_address_spaces
      destination_addresses = ["*"]
      destination_ports     = ["22", "3389"]
    }
  }
}

# Firewall logs flow to the central workspace when one is provided (offline
# default: no workspace id -> no diagnostic setting is created).
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "firewall-to-workspace"
  target_resource_id         = azurerm_firewall.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
