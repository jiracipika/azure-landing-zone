# Management group hierarchy (simplified Azure Landing Zone shape).
#
# Governance invariants (do not relax without a documented governance review):
# - the lab root "alz-root" is the SINGLE policy assignment target; every group
#   below it inherits the governance baseline assigned there;
# - platform concerns (management/connectivity) are separated from landing
#   zones (corp/online) so connectivity operators cannot mutate workload
#   subscriptions and vice versa;
# - sandbox and decommissioned sit directly under the root: sandbox is
#   deliberately OUTSIDE the landing zone branches (no inheritance of the
#   corporate network path), decommissioned is a quarantine stop before
#   subscription deletion.
#
# Tenant-level resources: deploying requires tenant_id + owner approval;
# nothing in this module runs while deploy_enabled = false.

resource "azurerm_management_group" "root" {
  display_name = "alz-root"
}

resource "azurerm_management_group" "platform" {
  display_name               = "alz-platform"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "management" {
  display_name               = "alz-management"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "connectivity" {
  display_name               = "alz-connectivity"
  parent_management_group_id = azurerm_management_group.platform.id
}

resource "azurerm_management_group" "landing_zones" {
  display_name               = "alz-landing-zones"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "corp" {
  display_name               = "alz-corp"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "online" {
  display_name               = "alz-online"
  parent_management_group_id = azurerm_management_group.landing_zones.id
}

resource "azurerm_management_group" "sandbox" {
  display_name               = "alz-sandbox"
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "decommissioned" {
  display_name               = "alz-decommissioned"
  parent_management_group_id = azurerm_management_group.root.id
}

locals {
  mg_ids = {
    root           = azurerm_management_group.root.id
    platform       = azurerm_management_group.platform.id
    management     = azurerm_management_group.management.id
    connectivity   = azurerm_management_group.connectivity.id
    landing_zones  = azurerm_management_group.landing_zones.id
    corp           = azurerm_management_group.corp.id
    online         = azurerm_management_group.online.id
    sandbox        = azurerm_management_group.sandbox.id
    decommissioned = azurerm_management_group.decommissioned.id
  }
}

# Placement of EXISTING subscriptions into the hierarchy. The map is empty by
# default; keys are validated so a typo cannot silently create associations to
# the wrong level (invalid keys fail the lookup with a plan-time error).
resource "azurerm_management_group_subscription_association" "this" {
  for_each = var.subscription_ids

  management_group_id = local.mg_ids[each.key]
  subscription_id     = each.value
}
