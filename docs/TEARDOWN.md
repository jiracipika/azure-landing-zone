# Safe cleanup

No deployed resources exist. When deployment is later approved, the complete
resource inventory created by this code is:

## Resource inventory (Terraform state scope)

| Resource | Terraform address | Notes |
|---|---|---|
| Management groups ×9 | `module.management_groups[0].azurerm_management_group.*` | tenant-level; deleting parents cascades children |
| Subscription associations | `module.management_groups[0].azurerm_management_group_subscription_association.this` | moves subscriptions back to their previous parent — verify placement BEFORE destroy |
| Policy definitions ×4 + initiative | `module.governance[0].azurerm_policy_definition.*`, `azurerm_policy_set_definition.governance_baseline` | |
| Policy assignment (+ managed identity) | `module.governance[0].azurerm_management_group_policy_assignment.governance_baseline` | destroy removes the remediation identity |
| Custom role + assignment | `module.access_control[0].azurerm_role_definition.spoke_operator`, `azurerm_role_assignment.spoke_operator` | |
| rg-alz-management + workspace | `module.observability[0].*` | workspace deletion loses all logs — export evidence first |
| rg-alz-connectivity: hub VNet, 3 subnets, 3 public IPs | `module.hub_network[0].*` | |
| Firewall + policy + rule collection group + diagnostics | `module.hub_network[0].azurerm_firewall.*` | |
| VPN gateway | `module.hub_network[0].azurerm_virtual_network_gateway.vpn` | |
| Bastion host | `module.hub_network[0].azurerm_bastion_host.this` | |
| Spokes (dev, prod): rg, VNet, subnet, NSG + rule, route table, 2 peerings each | `module.spoke_network["dev"/"prod"].*` | peerings must go before hub VNet deletion |
| Budgets ×2 | `module.budget_management[0]`, `module.budget_connectivity[0]` | |

## Approved cleanup plan (to execute only with owner authorization)

1. Confirm no subscriptions still sit under alz-sandbox/alz-decommissioned
   and none depend on the peerings or gateway (check first — subscription
   placement changes are visible in the portal before any destroy).
2. `terraform destroy` with the same `-var-file=environments/dev.tfvars` plus
   the deploy variables that were approved. Expected: ~30 resources destroyed
   (9 MGs, governance 6, RBAC 1–2, hub 12, spokes 2×9, budgets 2).
3. Destroy order is dependency-safe in code (peerings precede the hub; NSG
   rules precede NSGs), but verify no destroy-time errors leave management
   group children orphaned — re-run until state is empty.
4. Verify billable remnants: no orphaned public IPs, no firewall public IP,
   no Log Analytics workspace still ingesting (`az resource list` per resource
   group returns empty).
5. Management groups with children cannot be deleted — if Terraform leaves
   any, remove children first (portal/CLI), then the parents, then alz-root.

## Rollback short of destroy

- Flip `enforce = true` → `false` on the assignment to stop policy effect
  without deleting anything.
- Set `deploy_enabled = false` and re-apply: everything above is
  count/for_each gated, so the whole landing zone is removed from state
  management on the next apply — the same as destroy for drift purposes.
