# Spend safety

Azure spend authorized: $0. Never run cloud apply, premium gateway
provisioning, paid load tests or production identity changes without a
SKU/region quote and explicit approval. Budgets alert but do not cap
spending.

## Deployment price preparation (M3 input — estimates only)

Estimated **~US$1,175/month standing** if deployed exactly as coded
(canadacentral list-price ballpark, November 2026 — MUST be re-verified with
the Azure pricing calculator before any approval). This is a LAB: the numbers
exist to justify why the gate stays closed, not as a recommendation.

| Item | SKU / basis | Estimate |
|---|---|---|
| Azure Firewall | Standard, ~$1.25/hr standing + $0.016/GB | **~$913/mo** + data |
| Azure Bastion | Basic, ~$0.19/hr | ~$139/mo |
| VPN gateway | VpnGw1, ~$0.042/hr | ~$31/mo |
| Public IPs ×3 | Standard (firewall, bastion, gateway), ~$0.005/hr | ~$11/mo |
| Log Analytics | PerGB2018, ~$2.30/GB ingested | usage-based (firewall logs can be GBs) |
| Management groups, policy, RBAC, budgets, VNets, NSGs, routes, peerings | free tiers | $0 |

Cost levers, in order of impact:

1. **Firewall is 78% of the standing bill.** If the hub demo must go live
   cheaper: drop to Azure Firewall Basic where region-supported, or replace
   the hub with NAT-only egress + NSGs (loses L7 inspection and central
   logging), or deploy for a short window and destroy first.
2. **Bastion is the second standing charge.** Developer SKU (session billing)
   could replace Basic if the region supports it.
3. **VPN gateway**: destroy when no edge tunnel is being demonstrated.
4. **Log Analytics**: set `daily_quota_gb` on the workspace to cap ingestion;
   firewall DNS-proxy logging is chatty.
5. Budgets (50/80/100%) are wired on both resource groups but they ALERT,
   never block.

No resource in this repository may be created without the owner approving
this estimate first (M3 gate in docs/GLM_TASKS.md).
