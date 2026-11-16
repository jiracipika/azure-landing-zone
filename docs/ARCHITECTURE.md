# Architecture: Azure Landing Zone

Simplified Azure Landing Zone: a nine-node management group hierarchy with a
single policy baseline assigned at the lab root (inherited by everything
below), a scoped custom RBAC role, and a classic hub-spoke network — hub VNet
with Azure Firewall, route-based VPN gateway and Bastion; dev/prod spokes
peered to the hub and force-tunnelled through the firewall.

**Proof (all offline):** governance inheritance (assignment target + hierarchy
shape), policy compliance decisions (tests/policy_simulator.py replays the
real rules), and traffic/egress control (deny-all spokes, UDR to firewall,
firewall rule base).

## Implemented topology (as code, gated off by `deploy_enabled = false`)

| Element | Terraform | Notes |
|---|---|---|
| MG hierarchy (9 nodes) | `modules/management_groups` | root → platform (management, connectivity), landing-zones (corp, online), sandbox, decommissioned |
| Subscription placement | `modules/management_groups` | `azurerm_management_group_subscription_association` for `var.subscription_ids` (empty default: nothing moves) |
| Custom policies ×4 | `modules/governance/policy-definitions.tf` | allowed locations (Deny), allowed VM SKUs (Deny), require tag (Audit), deploy VM diagnostics (DeployIfNotExists) |
| Initiative + assignment | `modules/governance/policy-set.tf`, `policy-assignment.tf` | 5 references at alz-root, `enforce = false` (audit-first), SystemAssigned identity for DINE |
| Central workspace | `modules/observability` | `log-alz-management` (PerGB2018, 30-day retention, local auth disabled) |
| Hub VNet 10.20.0.0/22 | `modules/hub_network` | AzureFirewallSubnet /26, GatewaySubnet /27, AzureBastionSubnet /26 |
| Azure Firewall Standard | `modules/hub_network/firewall.tf` | policy `afwp-alz-hub` + rule group; diagnostics → workspace |
| VPN gateway | `modules/hub_network/gateway.tf` | VpnGw1 route-based (cheapest standing SKU) |
| Bastion Basic | `modules/hub_network/gateway.tf` | the only management entry (TLS 443) |
| Spokes dev/prod | `modules/spoke_network` (for_each) | 10.21.0.0/16, 10.22.0.0/16; deny-all-inbound NSG; UDR 0.0.0.0/0 → firewall; bidirectional peering with gateway transit |
| Scoped RBAC | `modules/access_control` | `alz-spoke-operator` custom role, assignable ONLY under alz-corp |
| Budgets | `modules/budget` ×2 | 50/80/100% alerts on management + connectivity resource groups |

## Management group hierarchy

```
Tenant Root Group
└── alz-root                    ← policy assignment lives here (inherits to ALL below)
    ├── alz-platform
    │   ├── alz-management       ← rg-alz-management, workspace, budget
    │   └── alz-connectivity     ← rg-alz-connectivity, hub VNet, firewall, VPN, Bastion, budget
    ├── alz-landing-zones
    │   ├── alz-corp             ← spokes dev/prod; ONLY scope of alz-spoke-operator
    │   └── alz-online
    ├── alz-sandbox              ← deliberately outside landing zone branches
    └── alz-decommissioned       ← quarantine before subscription deletion
```

## Policy baseline (assigned once at alz-root, audit-first)

| Policy | Mode | Effect | Fires when |
|---|---|---|---|
| alz-allowed-locations | All | **deny** | location ∉ {canadacentral, canadaeast, global} |
| alz-allowed-vm-skus | Indexed | **deny** | VM SKU ∉ low-cost B/D list (GPU/M/F blocked) |
| alz-require-tag (environment) | Indexed | **audit** | tag `environment` missing |
| alz-require-tag (costCenter) | Indexed | **audit** | tag `costCenter` missing |
| alz-deploy-vm-diagnostics | Indexed | **deployIfNotExists** | VM has no diagnostic setting → the central workspace (embeds the remediation ARM template; requires the assignment's SystemAssigned identity + built-in Contributor role id) |

`enforce = false` is deliberate: audit-first rollout — nothing is denied or
remediated until the owner flips it after reviewing compliance results.
Simulation decisions for compliant and violating resources are asserted in
tests/test_landing_zone.py (`GovernanceDecisions`).

## Firewall rule base (arcg-alz-hub)

| Collection | Priority | Action | Rule | Source | Ports | Effect |
|---|---|---|---|---|---|---|
| allow-spoke-egress | 100 | Allow | allow-dns | spoke CIDRs | UDP 53 | name resolution |
| allow-spoke-egress | 100 | Allow | allow-web | spoke CIDRs | TCP 80, 443 | vetted web egress |
| deny-spoke-mgmt-egress | 200 | Deny | deny-ssh-rdp-egress | spoke CIDRs | TCP 22, 3389 | explicit management-egress block |

Everything else falls to the firewall's implicit deny. Firewall logs
(network/application/DNS-proxy rules + AllMetrics) flow to the central
workspace when one is wired.

## Traffic flows and trust boundaries

1. **Public Internet** → may ONLY reach Bastion :443 (TLS). No workload
   listener is public: spoke NSGs carry a single explicit Deny-All-Inbound
   (priority 4096) plus platform defaults.
2. **Spoke workloads** → egress is force-tunnelled: UDR `0.0.0.0/0 →
   firewall` (VirtualAppliance next hop), `default_outbound_access_enabled =
   false`, so no implicit egress IPs exist.
3. **On-premises / lab edge** → IPsec to the VPN gateway; spokes use remote
   gateways over the peering (`use_remote_gateways` spoke-side, gateway
   transit hub-side).
4. **Management plane** → Bastion only; SSH/RDP egress to the Internet is
   explicitly denied at the firewall.
5. **Governance plane** → one assignment at alz-root; platform, landing
   zones, sandbox and decommissioned all inherit; RBAC escalation is bounded
   (alz-spoke-operator is assignable only under alz-corp, no wildcard
   actions).
6. **CI** → read-only offline checks; no credentials, no deploy step.

## Architecture decisions and flaws considered

- **Classic hub, not Virtual WAN**: vWAN adds per-hub costs and abstractions
  this lab does not need; a plain hub VNet keeps every control inspectable.
- **Firewall Standard (~$0.9k/mo standing) is the elephant**: it dominates the
  cost estimate; a deployable variant with Azure Firewall Premium → Basic or
  an NAT-only "hub-lite" is a documented future option (docs/COSTS.md).
- **Deny-all spokes**: starting from "no inbound anywhere" forces every
  future ingress to be a deliberate, reviewed change — the opposite of the
  common any-any default.
- **Health of policy rollout**: Deny policies deployed with `enforce=false`
  first; flipping to enforce happens only after audit results are reviewed —
  the standard safe-rollout discipline.
- **Known lab limitations (accepted)**: VPN gateway has no local network
  gateway / connections yet (edge config is owner-specific); spokes contain
  no workload resources yet — the landing zone is the deliverable; Bastion
  Basic lacks native-client support.

This is validated code, not a deployed system: `deploy_enabled = false`
means `terraform plan` proposes zero resources (verified offline).
