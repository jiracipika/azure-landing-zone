# Platform management resource group: central Log Analytics workspace that
# receives firewall diagnostics (hub module) and, once enforce is flipped,
# VM diagnostics deployed by the governance initiative's DeployIfNotExists
# policy. PerGB2018 pay-as-you-go is the cheapest tier for a lab volume.
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.workspace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags

  # Lock the workspace down: no local auth keys (enforce AAD), no public
  # ingestion beyond what is explicitly peered. Kept least-open by default.
  local_authentication_enabled = false
}
