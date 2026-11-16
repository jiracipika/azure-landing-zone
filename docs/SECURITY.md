# Security requirements

No secrets, state, privileged tokens, public SSH/RDP or customer data in git.
Pin or review CI dependencies, scope federated identity, apply least
privilege, block unauthorized network paths and log denial tests. Never apply
tenant-level changes automatically.

## Controls implemented (offline-verified)

| Control | Where | Test |
|---|---|---|
| Deploy gate default OFF | `infra/terraform/variables.tf` | `test_deploy_disabled_by_default` + scaffold tests |
| Every root module gated (7 count + 1 for_each) | `infra/terraform/main.tf` | `test_every_root_module_is_gated` |
| Management group hierarchy shape (9 nodes, inheritance path to corp/online) | `modules/management_groups` | `ManagementGroupHierarchy` |
| Governance assigned ONCE at alz-root → inherited | `modules/governance/policy-assignment.tf` + root wiring | `GovernanceInheritance` |
| Audit-first rollout (`enforce = false`) | same | `test_rollout_is_audit_first` |
| DINE remediation identity is SystemAssigned + built-in Contributor only | same + policy rule | `test_dine_reference_requires_system_assigned_identity` |
| Out-of-region resources DENIED; portfolio region allowed | `alz-allowed-locations` | `test_out_of_region_resource_is_denied` |
| GPU/oversized VM SKUs DENIED; low-cost list allowed | `alz-allowed-vm-skus` | `test_gpu_and_oversized_skus_are_denied` |
| Missing mandatory tags AUDITED (environment, costCenter separately) | `alz-require-tag` ×2 | `test_untagged_resource_is_audited_for_both_mandatory_tags` |
| VMs without workspace-backed diagnostics trigger DINE (wrong workspace ≠ compliant) | `alz-deploy-vm-diagnostics` | `test_vm_with_wrong_workspace_still_triggers_dine` |
| Custom role assignable ONLY under alz-corp; no wildcard actions | `modules/access_control` | `ScopedRbac` |
| Role assignment inert without a real principal | `modules/access_control` | `test_assignment_scope_is_corp_and_principal_is_inert_by_default` |
| Spokes deny ALL inbound by default (no Allow rule exists) | `modules/spoke_network` | `test_no_inbound_allow_rules_anywhere_in_spokes` |
| Spoke egress force-tunnelled to firewall; no default outbound | `modules/spoke_network` | `test_default_route_points_at_hub_firewall`, `test_workload_subnet_disables_default_outbound` |
| Firewall denies SSH/RDP egress; allows only DNS + web | `modules/hub_network/firewall.tf` | `test_firewall_rule_base` |
| Firewall logs to central workspace | same | `test_firewall_logs_to_central_workspace_when_wired` |
| Workspace local authentication disabled | `modules/observability` | `test_workspace_is_locked_down` |
| Placeholder subscription/tenant ids; no real GUIDs in git (only zeros + public Contributor role id) | `variables.tf` + scan | `test_placeholder_subscription_and_tenant_ids`, `test_no_real_guids_anywhere_in_terraform` |
| Budgets alert at 50/80/100% per resource group | `modules/budget` | `BudgetGuardrails` |
| CI read-only, no apply/destroy/login/oidc, pinned TF | `.github/workflows/validate.yml` | `CiSafety` |

## Residual risks / not yet implemented

- Budgets alert but do not cap spending; real protection is the deploy gate
  staying closed and the owner reviewing COSTS.md first.
- VPN gateway has no connections/local network gateway configured yet —
  edge-specific configuration is deferred to the owner (no static edge IPs in
  a portfolio repo).
- Policy assignment identity needs a real tenant to materialize; offline it is
  only schema-validated.
- No Checkov/tflint in CI yet (future milestone per GLM_TASKS.md M2).
- `terraform plan` offline stops at the provider authorizer (no `az` CLI or
  credentials in the sandbox) — expected; validate + the unit battery are the
  CI gate.
