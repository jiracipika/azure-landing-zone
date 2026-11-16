# Project tasks: Azure Landing Zone

## M0 foundation
- [x] GitHub README and agent instructions
- [x] Terraform offline root, static validation pipeline, test baseline
- [ ] Confirm GitHub Actions result with real run

## M1 offline work
- [ ] Implement detailed Management group hierarchy, Azure Policy, hub VNet, Azure Firewall, VPN Gateway, Bastion and dev/prod spokes architecture with modular infrastructure code
- [ ] Create deterministic demonstrations for demonstrate governance inheritance, scoped rbac and policy compliance
- [ ] Write happy- and negative-path automated tests
- [ ] Update diagram with correct traffic flows, roles and limits
- [ ] Run terraform fmt/init -backend=false/validate and unittest and record evidence

## M2 secure implementation
- [ ] Define resource SKUs, network restrictions, IAM permissions and service prerequisites
- [ ] Create risk/abuse test matrix; remove unsafe defaults
- [ ] Add lint, secret scan and infrastructure security checks

## M3 approval gate
- [ ] Itemize regional monthly/hours cost and teardown plan
- [ ] Await owner approval before any cloud deployment
- [ ] Capture real performance, recovery, cost and validation results only if live approved
