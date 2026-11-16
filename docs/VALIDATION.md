# Evidence log

Every entry below is an actual command execution with its real result. Azure
live deployment: **NOT RUN** (no authorization; offline `terraform plan` also
stops at the provider authorizer because the sandbox has no `az` CLI or
credentials — expected, not a code failure).

## 2026-11-16T14:34Z — local offline battery (GLM/ZCode session, terraform v1.9.8, azurerm 4.81.0)

| Command | Result | Evidence |
|---|---|---|
| `python3 -m unittest discover -s tests` | **PASS** | `Ran 64 tests ... OK` |
| `terraform -chdir=infra/terraform fmt -check -recursive` | **PASS** | exit 0 after fixes |
| `terraform -chdir=infra/terraform init -backend=false -input=false` | **PASS** | azurerm v4.81.0; 7 modules loaded |
| `terraform -chdir=infra/terraform validate` | **PASS** | `Success! The configuration is valid.` |
| `terraform -chdir=infra/terraform plan -input=false -refresh=false` | **PARTIAL (expected)** | proposes only `+ status = "offline-scaffold-only"` (zero resources — deploy gate holds); then errors `could not configure AzureCli Authorizer: az: executable file not found` |

### Failures found and fixed during this run (real history)

1. `fmt -check` failed on scaffold `variables.tf` (non-canonical scaffold
   formatting) — fixed with `terraform fmt -recursive`; this was also the
   root cause of the two red CI runs below.
2. First test run (64 tests): 6 failures + 1 error, all test-side, no
   Terraform changes needed —
   (a) the management-group hierarchy parser used a fragile single regex with
   a negative lookahead that matched only the first group; replaced with the
   brace-matching block scanner shared with policy_simulator (`ps._blocks`);
   (b) `test_hub_firewall_ip_wired_from_hub_module` asserted a
   `firewall_private_ip = var.firewall_private_ip` line that legitimately
   does not exist in the spoke module (the variable is only used inside the
   route); the test now asserts the root wiring plus the route-table usage;
   (c) the diagram test failed because diagrams/architecture.mmd was still
   the scaffold stub — the diagram was rewritten to match the implemented
   architecture (the failure was the documentation being stale, which is
   exactly what the test exists to catch).
3. Provider schema corrections applied BEFORE writing resources (no
   validate churn): `azurerm_management_group.parent_management_group_id`
   (not `parent_id`), policy assignment uses `management_group_id` + `enforce`
   (bool, not `scope`/`enforcement_mode`), budget notifications are a
   `notification` set-block, `azurerm_route_table.route` is an attribute, and
   the VPN gateway `generation` is computed from the SKU (omitted).

### Schema verification method (as required)

Provider attributes were verified against the installed provider, not
guessed: `terraform -chdir=infra/terraform providers schema -json` (azurerm
4.81.0) confirmed every resource/block used above, including
`azurerm_firewall.ip_configuration {name, subnet_id, public_ip_address_id}`,
`azurerm_firewall_policy_rule_collection_group` collection/rule nesting,
`azurerm_management_group_policy_assignment.identity {type}` +
`log_analytics_workspace_id` on diagnostic settings, and the provider-level
`subscription_id`/`tenant_id` attributes used in providers.tf.

GitHub Actions run recorded below after pushing this commit.

| Date | Run | Conclusion |
|---|---|---|
| 2026-11-16T13:24Z | 43875452924 (scaffold) | failure — `fmt -check` exit 3 on variables.tf |
| 2026-11-16T13:26Z | 43875774824 (scaffold) | failure — `fmt -check` exit 3 on variables.tf |
| 2026-11-16T14:36Z | 43887439076 (implementation, commit 7794379) | **success — 64 tests + fmt + init + validate green on ubuntu runner / terraform 1.10.5** |
