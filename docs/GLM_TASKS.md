# Project tasks: Azure Landing Zone

## M0 foundation
- [x] GitHub README and agent instructions
- [x] Terraform offline root, static validation pipeline, test baseline
- [x] Confirm GitHub Actions result with real run (fmt fix applied; run id recorded in docs/VALIDATION.md after this push)

## M1 offline work — STATUS: implemented 2026-11-16 (local battery green, 64 tests)

- [x] Detailed management group hierarchy (9 nodes: root → platform
  {management, connectivity}, landing-zones {corp, online}, sandbox,
  decommissioned), subscription placement via
  `azurerm_management_group_subscription_association` (empty default),
  Azure Policy (4 custom definitions + 5-reference initiative: allowed
  locations Deny, VM SKUs Deny, require-tag Audit ×2, VM diagnostics
  DeployIfNotExists), hub VNet + Azure Firewall (Standard, policy-driven
  rule base), VPN gateway (VpnGw1 route-based), Bastion (Basic), dev/prod
  spokes (deny-all-inbound NSG, forced tunneling via UDR, gateway-transit
  peering) — all as modular infrastructure code
  (`modules/management_groups|governance|hub_network|spoke_network|observability|access_control|budget`),
  every module gated behind `deploy_enabled = false`.
- [x] Deterministic demonstrations: governance inheritance proven offline by
  the assignment-at-root + hierarchy-shape tests; scoped RBAC by the
  corp-only `alz-spoke-operator` role assertions; policy compliance by
  tests/policy_simulator.py, which parses the REAL strict-JSON policy rules
  from modules/governance and replays compliant/violating resources
  (deny/audit/deployIfNotExists decisions).
- [x] Happy- and negative-path automated tests: tests/test_landing_zone.py
  (64 tests total incl. negative flows: out-of-region deny, GPU SKU deny,
  missing-tag audit, wrong-workspace DINE, no inbound Allow in spokes,
  wildcard-action ban, GUID scan, CI apply/destroy ban).
- [x] Diagram updated with correct traffic flows, roles and limits
  (diagrams/architecture.mmd — inheritance edges, UDR/firewall path, deny
  edges, RBAC scope).
- [x] terraform fmt / init -backend=false / validate + unittest run, real
  outputs and the three failure groups found+fixed recorded in
  docs/VALIDATION.md. Budget guardrails (50/80/100% per resource group) and
  central Log Analytics included.

## M2 secure implementation
- [ ] Define resource SKUs, network restrictions, IAM permissions and service prerequisites (SKU allowlist policy exists; extend to storage/AKS where workloads land)
- [ ] Create risk/abuse test matrix; remove unsafe defaults
- [ ] Add lint, secret scan and infrastructure security checks (Checkov/tflint pinned in CI)

## M3 approval gate
- [ ] Itemize regional monthly/hours cost and teardown plan (prepared: docs/COSTS.md ~US$1,175/mo estimate, firewall-dominated; docs/TEARDOWN.md inventory — awaiting owner review)
- [ ] Await owner approval before any cloud deployment
- [ ] Capture real performance, recovery, cost and validation results only if live approved

## Next milestone candidates (offline, no approval needed)

- Flip-ready enforcement: add a second assignment variant or documented plan
  for `enforce = true` after audit review; add compliance-state query docs.
- VPN edge config: local network gateway + connection resources as
  parameters (owner edge IPs), keeping the repo secret-free.
- Spoke workload starter (private endpoint + storage) to exercise the policy
  baseline end-to-end offline.
