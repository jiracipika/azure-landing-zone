# 05 — Azure Landing Zone

**Azure Cloud Engineering Portfolio** · [GitHub: jiracipika](https://github.com/jiracipika) · **PRIVATE repository** · **Offline scaffold / Azure NOT DEPLOYED**

## Goal
Demonstrate compliant resource governance and least-privilege infrastructure.

## Architecture (implemented as code, gated off)
Simplified Azure Landing Zone: a nine-node management group hierarchy with one
governance baseline (allowed locations **Deny**, VM SKUs **Deny**, mandatory
tags **Audit**, VM diagnostics **DeployIfNotExists**) assigned at the lab root
and inherited by every descendant; a corp-only least-privilege custom role; a
hub VNet with Azure Firewall (DNS/web-only egress rule base, explicit SSH/RDP
egress deny), route-based VPN gateway (VpnGw1) and Bastion; dev/prod spokes
with deny-all-inbound NSGs, force-tunnelled through the firewall; central Log
Analytics; budget alerts (50/80/100%) per resource group. Proven offline by
tests/policy_simulator.py, which parses the real policy rules out of the
Terraform and replays allow/deny/audit/remediate decisions.

## GLM / ZCode — start here

1. Read [AGENTS.md](AGENTS.md), [GLM tasks](docs/GLM_TASKS.md), [architecture](docs/ARCHITECTURE.md), [security](docs/SECURITY.md), and [validation](docs/VALIDATION.md).
2. Implement the next offline milestone in **docs/GLM_TASKS.md** with runnable code and negative tests, not just a plan.
3. Verify Terraform syntax and security, run unit tests, record actual results, and keep diagrams/documentation current.
4. **Do not apply Terraform or deploy any billable Azure resources or alter cloud IAM without my explicit approval.**
5. Report changed files, actual tests and blockers in your ZCode session and commits.

## Offline starting commands

```sh
python3 -m unittest discover -s tests -v
terraform -chdir=infra/terraform fmt -check -recursive
terraform -chdir=infra/terraform init -backend=false -input=false
terraform -chdir=infra/terraform validate
```

All four pass locally (64 tests) — see docs/VALIDATION.md for the real
output log, including the failures that were found and fixed.

## Source contents

- `AGENTS.md`: enforceable GLM implementation contract
- `docs/GLM_TASKS.md`: project-specific milestones and current status
- `docs/ARCHITECTURE.md`: hierarchy, policy matrix, firewall rules, trust boundaries
- `docs/SECURITY.md` / `docs/COSTS.md`: controls table, guardrails, cost estimate (~US$1,175/mo if deployed — firewall-dominated)
- `docs/VALIDATION.md`: real evidence only — actual commands and results
- `docs/TEARDOWN.md`: resource inventory + approved cleanup plan
- `diagrams/architecture.mmd`: editable Mermaid model with governance and traffic edges
- `infra/terraform/`: root module + 7 child modules (`management_groups`, `governance`, `hub_network`, `spoke_network`, `observability`, `access_control`, `budget`); everything gated by `deploy_enabled=false`
- `infra/terraform/environments/dev.tfvars`: offline-safe defaults
- `.github/workflows/validate.yml`: offline validation, no deploy step
- `tests/`: scaffold gates, landing zone invariants and the policy simulator

## Status and safety

Terraform modules for the full landing zone topology are implemented and
validated offline; **no Azure services are deployed** and `terraform plan`
with defaults proposes zero resources. Repository visibility must remain
**PRIVATE**. No credentials, secrets, real customer data, Terraform state or
internal account identifiers may be committed.
