# Scoped RBAC demonstration: a custom least-privilege role that may join
# workloads to spoke networks and manage spoke NSGs, assignable ONLY inside
# the corp landing zone — never the root, the platform branch or the whole
# tenant. Connectivity operators therefore cannot escalate into governance.
resource "azurerm_role_definition" "spoke_operator" {
  name        = "alz-spoke-operator"
  scope       = var.root_management_group_id
  description = "Join VMs to spoke subnets and manage spoke NSGs. Assignable only under the corp landing zone."

  permissions {
    actions = [
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/networkSecurityGroups/read",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Network/routeTables/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
    ]

    not_actions = []
  }

  assignable_scopes = [var.corp_management_group_id]
}

# Assignment to a workload team principal. Inert until a real principal object
# id is supplied (empty default), and still count-gated by deploy_enabled at
# the root module.
resource "azurerm_role_assignment" "spoke_operator" {
  count = var.principal_id != "" ? 1 : 0

  scope              = var.corp_management_group_id
  role_definition_id = azurerm_role_definition.spoke_operator.role_definition_resource_id
  principal_id       = var.principal_id
}
