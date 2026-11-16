"""Landing zone invariants — parsed from the actual Terraform sources.

Two layers of offline proof:
1. Policy simulation: tests/policy_simulator.py parses the REAL custom policy
   definitions (strict-JSON heredocs in modules/governance) and replays
   resources through the rules — proving Deny/Audit/DeployIfNotExists decisions
   against the exact rule text Terraform would submit.
2. Structural invariants: management group hierarchy shape, governance
   inheritance (assignment at the root, descendants below), scoped RBAC,
   hub/spoke wiring (default-deny spokes, forced tunneling, firewall rule
   base), budget guardrails, deploy gating and CI safety — regex assertions
   that survive terraform fmt realignment.
"""

from pathlib import Path
import re
import unittest

import policy_simulator as ps

ROOT = Path(__file__).resolve().parents[1]
TF = ROOT / "infra" / "terraform"


def read(rel: str) -> str:
    return (TF / rel).read_text()


# --- Governance decisions (policy simulation) ----------------------------------

class PolicySimulatorSanity(unittest.TestCase):
    """The simulator must see the definitions the HCL actually declares."""

    def test_definitions_parse_and_names_are_alz_namespaced(self):
        defs = ps.load_definitions()
        self.assertEqual(len(defs), 4)
        for key, d in defs.items():
            self.assertTrue(d["name"].startswith("alz-"),
                            f"{key} policy name must be alz-namespaced")

    def test_effect_mix_is_denied_locations_skus_audit_tags_dine_diagnostics(self):
        defs = ps.load_definitions()
        effects = {d["name"]: d["rule"]["then"]["effect"] for d in defs.values()}
        self.assertEqual(effects["alz-allowed-locations"], "deny")
        self.assertEqual(effects["alz-allowed-vm-skus"], "deny")
        self.assertEqual(effects["alz-require-tag"], "audit")
        self.assertEqual(effects["alz-deploy-vm-diagnostics"], "deployIfNotExists")

    def test_initiative_references_every_definition(self):
        initiative = ps.load_initiative()
        referenced = {r["definition_key"] for r in initiative["references"]}
        self.assertEqual(referenced, set(ps.load_definitions().keys()))
        self.assertEqual(len(initiative["references"]), 5,
                         "require_tag is referenced twice (environment + costCenter)")


class GovernanceDecisions(unittest.TestCase):
    """Happy and negative paths replayed through the real policy rules."""

    @classmethod
    def setUpClass(cls):
        cls.params = ps.default_assignment_params()

    def evaluate(self, resource):
        return dict(ps.evaluate_initiative(resource, self.params))

    def test_fully_compliant_vm_triggers_nothing(self):
        vm = {
            "type": "Microsoft.Compute/virtualMachines",
            "location": "canadacentral",
            "sku": {"name": "Standard_B1s"},
            "tags": {"environment": "dev", "costCenter": "cc-123"},
            "diagnosticSettings": [
                {"properties": {"workspaceId": self.params["workspaceResourceId"]}}
            ],
        }
        self.assertEqual(self.evaluate(vm), {})

    def test_out_of_region_resource_is_denied(self):
        for location in ("eastus", "westeurope", "brazilsouth"):
            fired = self.evaluate({"type": "Microsoft.Storage/storageAccounts", "location": location})
            self.assertEqual(fired.get("allowed_locations"), "deny", location)

    def test_allowed_regions_including_global_pass_locations_policy(self):
        for location in ("canadacentral", "canadaeast", "global"):
            fired = self.evaluate({"type": "Microsoft.Storage/storageAccounts", "location": location})
            self.assertNotIn("allowed_locations", fired, location)

    def test_gpu_and_oversized_skus_are_denied(self):
        for sku in ("Standard_NC4as_T4_v3", "Standard_M128s", "Standard_F72s_v2"):
            fired = self.evaluate({
                "type": "Microsoft.Compute/virtualMachines",
                "location": "canadacentral",
                "sku": {"name": sku},
                "tags": {"environment": "dev", "costCenter": "cc-123"},
                "diagnosticSettings": [
                    {"properties": {"workspaceId": self.params["workspaceResourceId"]}}
                ],
            })
            self.assertEqual(fired.get("allowed_vm_skus"), "deny", sku)

    def test_low_cost_skus_pass(self):
        for sku in ("Standard_B1s", "Standard_B2s", "Standard_B2ms", "Standard_D2s_v5"):
            fired = self.evaluate({
                "type": "Microsoft.Compute/virtualMachines",
                "location": "canadacentral",
                "sku": {"name": sku},
                "tags": {"environment": "dev", "costCenter": "cc-123"},
                "diagnosticSettings": [
                    {"properties": {"workspaceId": self.params["workspaceResourceId"]}}
                ],
            })
            self.assertNotIn("allowed_vm_skus", fired, sku)

    def test_untagged_resource_is_audited_for_both_mandatory_tags(self):
        fired = self.evaluate({
            "type": "Microsoft.Storage/storageAccounts",
            "location": "canadacentral",
        })
        self.assertEqual(fired.get("require_tag_environment"), "audit")
        self.assertEqual(fired.get("require_tag_cost_center"), "audit")

    def test_partial_tags_audit_only_the_missing_tag(self):
        fired = self.evaluate({
            "type": "Microsoft.Storage/storageAccounts",
            "location": "canadacentral",
            "tags": {"environment": "prod"},
        })
        self.assertNotIn("require_tag_environment", fired)
        self.assertEqual(fired.get("require_tag_cost_center"), "audit")

    def test_vm_without_diagnostics_triggers_deploy_if_not_exists(self):
        fired = self.evaluate({
            "type": "Microsoft.Compute/virtualMachines",
            "location": "canadacentral",
            "sku": {"name": "Standard_B1s"},
            "tags": {"environment": "dev", "costCenter": "cc-123"},
        })
        self.assertEqual(fired.get("deploy_vm_diagnostics"), "deployIfNotExists")

    def test_vm_with_wrong_workspace_still_triggers_dine(self):
        fired = self.evaluate({
            "type": "Microsoft.Compute/virtualMachines",
            "location": "canadacentral",
            "sku": {"name": "Standard_B1s"},
            "tags": {"environment": "dev", "costCenter": "cc-123"},
            "diagnosticSettings": [
                {"properties": {"workspaceId": "/subscriptions/11111111-1111-1111-1111-111111111111/workspaces/other"}}
            ],
        })
        self.assertEqual(fired.get("deploy_vm_diagnostics"), "deployIfNotExists",
                         "a setting pointing at the WRONG workspace must not count as compliant")

    def test_default_allowed_locations_contain_portfolio_region(self):
        self.assertIn("canadacentral", self.params["allowedLocations"])
        self.assertIn("global", self.params["allowedLocations"])

    def test_default_sku_allowlist_is_low_cost_only(self):
        for sku in self.params["allowedVmSkus"]:
            self.assertRegex(sku, r"^Standard_(B|D)\d", f"{sku} must be a low-cost B/D-series SKU")


# --- Management group hierarchy shape -------------------------------------------

class ManagementGroupHierarchy(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        src = read("modules/management_groups/main.tf")
        cls.groups = {}
        for key, block in ps._blocks(src, "azurerm_management_group"):
            display = re.search(r'^\s{2}display_name\s+= "([^"]+)"', block, re.M)
            parent = re.search(
                r'^\s{2}parent_management_group_id\s+= azurerm_management_group\.(\w+)\.id',
                block, re.M)
            if not display:
                raise ValueError(f"management group {key} has no display_name — parser drift")
            cls.groups[key] = {
                "display_name": display.group(1),
                "parent": parent.group(1) if parent else None,
            }
        if not cls.groups:
            raise ValueError("no management groups parsed — parser and HCL drifted")

    def children(self, key):
        return {k for k, v in self.groups.items() if v["parent"] == key}

    def test_nine_groups_expected_shape(self):
        self.assertEqual(len(self.groups), 9)

    def test_root_has_no_parent(self):
        self.assertIsNone(self.groups["root"]["parent"])
        self.assertEqual(self.groups["root"]["display_name"], "alz-root")

    def test_root_children_are_platform_landing_zones_sandbox_decommissioned(self):
        self.assertEqual(self.children("root"),
                         {"platform", "landing_zones", "sandbox", "decommissioned"})

    def test_platform_children_are_management_and_connectivity(self):
        self.assertEqual(self.children("platform"), {"management", "connectivity"})

    def test_landing_zones_children_are_corp_and_online(self):
        self.assertEqual(self.children("landing_zones"), {"corp", "online"})

    def test_corp_and_online_are_leaves_inheriting_from_root(self):
        # Inheritance chain corp -> landing_zones -> root: policy assigned at
        # root MUST reach the corp/online landing zones.
        self.assertEqual(self.children("corp"), set())
        self.assertEqual(self.children("online"), set())
        self.assertEqual(self.groups["corp"]["parent"], "landing_zones")
        self.assertEqual(self.groups["landing_zones"]["parent"], "root")

    def test_all_display_names_are_alz_namespaced(self):
        for v in self.groups.values():
            self.assertTrue(v["display_name"].startswith("alz-"), v["display_name"])

    def test_subscription_association_targets_validated_nodes(self):
        src = read("modules/management_groups/main.tf")
        self.assertRegex(src, r"for_each\s*=\s*var\.subscription_ids")
        self.assertRegex(src, r"management_group_id\s*=\s*local\.mg_ids\[each\.key\]")
        local_map = re.search(r"mg_ids = \{(.*?)\n\}", src, re.S).group(1)
        for node in self.groups:
            self.assertRegex(local_map, rf"\b{node}\s*=")
        # plan-time key validation exists in the module variables
        self.assertIn("error_message", read("modules/management_groups/variables.tf"))


# --- Governance inheritance wiring ----------------------------------------------

class GovernanceInheritance(unittest.TestCase):
    """Proof: the baseline is assigned once at alz-root, so all 8 descendants
    inherit it; rollout is audit-first (enforce=false); the DINE reference
    carries a remediation identity."""

    def test_assignment_targets_root_management_group(self):
        assignment = ps.load_assignment()
        self.assertEqual(assignment["management_group_id"], "var.root_management_group_id")

    def test_root_wires_assignment_scope_to_management_groups_root_output(self):
        main = read("main.tf")
        self.assertRegex(main, r"root_management_group_id\s+=\s*one\(module\.management_groups\[\*\]\.root_management_group_id\)")
        self.assertIn(
            "value       = azurerm_management_group.root.id",
            read("modules/management_groups/outputs.tf"),
        )

    def test_rollout_is_audit_first(self):
        self.assertFalse(ps.load_assignment()["enforce"])

    def test_dine_reference_requires_system_assigned_identity(self):
        assignment = ps.load_assignment()
        self.assertEqual(assignment["identity_type"], "SystemAssigned")
        defs = ps.load_definitions()
        dine = defs["deploy_vm_diagnostics"]["rule"]["then"]["details"]
        self.assertEqual(dine["roleDefinitionIds"], [ps.CONTRIBUTOR_ROLE_ID])
        self.assertIn("deployment", dine, "DINE policy must embed a remediation template")

    def test_definitions_are_stored_at_the_root_scope(self):
        for path in (TF / "modules/governance").glob("*.tf"):
            for block in re.finditer(
                r'resource "azurerm_policy_definition" "(\w+)" \{', path.read_text()
            ):
                self.assertIn("var.root_management_group_id", path.read_text())


# --- Scoped RBAC ------------------------------------------------------------------

class ScopedRbac(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.src = read("modules/access_control/main.tf")

    def test_role_definition_stored_at_root_scope(self):
        self.assertRegex(self.src, r'scope\s+=\s*var\.root_management_group_id')

    def test_role_is_assignable_only_in_corp_landing_zone(self):
        self.assertRegex(self.src, r'assignable_scopes\s+=\s*\[var\.corp_management_group_id\]')
        self.assertNotRegex(self.src, r'assignable_scopes\s*=\s*\[\s*"/"\s*\]')
        self.assertNotIn("var.root_management_group_id\n  }\n\n  assignable_scopes",
                         self.src)

    def test_no_wildcard_actions(self):
        actions = re.search(r"actions = \[(.*?)\]", self.src, re.S).group(1)
        for action in re.findall(r'"([^"]+)"', actions):
            self.assertNotEqual(action, "*")
            self.assertFalse(action.endswith("/*") or action.startswith("*"))

    def test_assignment_scope_is_corp_and_principal_is_inert_by_default(self):
        self.assertRegex(self.src, r'scope\s+=\s*var\.corp_management_group_id')
        self.assertRegex(self.src, r'count\s*=\s*var\.principal_id != "" \? 1 : 0')
        variables = read("modules/access_control/variables.tf")
        self.assertRegex(variables, r'"principal_id"\s*\{[^}]*default\s*=\s*""')

    def test_root_wires_corp_scope_from_management_groups(self):
        main = read("main.tf")
        self.assertRegex(main, r"corp_management_group_id\s*=\s*one\(module\.management_groups\[\*\]\.corp_management_group_id\)")


# --- Hub and spoke wiring ------------------------------------------------------------

class HubTopology(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.main = read("modules/hub_network/main.tf")
        cls.firewall = read("modules/hub_network/firewall.tf")

    def test_required_specialized_subnets_exist(self):
        for subnet in ("AzureFirewallSubnet", "GatewaySubnet", "AzureBastionSubnet"):
            self.assertIn(f'"{subnet}"', self.main, f"{subnet} missing from hub")

    def test_firewall_is_standard_tier_vnet_attached_to_policy(self):
        self.assertRegex(self.firewall, r'sku_name\s*=\s*"AZFW_VNet"')
        self.assertRegex(self.firewall, r'sku_tier\s*=\s*"Standard"')
        self.assertRegex(self.firewall, r'firewall_policy_id\s*=\s*azurerm_firewall_policy\.this\.id')
        self.assertRegex(self.firewall, r'subnet_id\s*=\s*azurerm_subnet\.firewall\.id')

    def test_firewall_rule_base(self):
        self.assertRegex(self.firewall, r'allow-dns')
        self.assertRegex(self.firewall, r'"UDP"')
        self.assertRegex(self.firewall, r'"53"')
        self.assertRegex(self.firewall, r'allow-web')
        self.assertRegex(self.firewall, r'"80",\s*"443"')
        # explicit deny of management egress, separate collection at lower priority
        self.assertRegex(self.firewall, r'deny-ssh-rdp-egress')
        self.assertRegex(self.firewall, r'"22",\s*"3389"')
        self.assertRegex(self.firewall, r'action\s*=\s*"Deny"')
        # rules are scoped to the spoke address spaces passed from the root
        self.assertRegex(self.firewall, r'source_addresses\s*=\s*var\.spoke_address_spaces')
        self.assertRegex(read("main.tf"), r'spoke_address_spaces\s*=\s*\[for s in var\.spokes : s\.address_space\]')

    def test_firewall_logs_to_central_workspace_when_wired(self):
        self.assertRegex(self.firewall, r'count\s*=\s*var\.log_analytics_workspace_id != "" \? 1 : 0')
        self.assertRegex(self.firewall, r'log_analytics_workspace_id\s*=\s*var\.log_analytics_workspace_id')
        for category in ("AzureFirewallNetworkRule", "AzureFirewallApplicationRule", "AzureFirewallDnsProxy"):
            self.assertIn(category, self.firewall)

    def test_vpn_gateway_is_route_based_cheapest_sku_variable(self):
        gateway = read("modules/hub_network/gateway.tf")
        self.assertRegex(gateway, r'type\s*=\s*"Vpn"')
        self.assertRegex(gateway, r'vpn_type\s*=\s*"RouteBased"')
        self.assertRegex(gateway, r'sku\s*=\s*var\.vpn_gateway_sku')
        self.assertRegex(read("variables.tf"), r'"vpn_gateway_sku"\s*\{[^}]*default\s*=\s*"VpnGw1"')

    def test_bastion_is_only_management_entry(self):
        gateway = read("modules/hub_network/gateway.tf")
        self.assertRegex(gateway, r'subnet_id\s*=\s*azurerm_subnet\.bastion\.id')


class SpokeIsolation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.src = read("modules/spoke_network/main.tf")

    def test_no_inbound_allow_rules_anywhere_in_spokes(self):
        self.assertNotRegex(self.src, r'access\s*=\s*"Allow"', "spokes must not allow any inbound traffic by default")

    def test_explicit_deny_all_inbound(self):
        self.assertRegex(self.src, r'access\s*=\s*"Deny"')
        self.assertRegex(self.src, r'direction\s*=\s*"Inbound"')
        self.assertRegex(self.src, r'priority\s*=\s*4096')

    def test_workload_subnet_disables_default_outbound(self):
        self.assertRegex(self.src, r'default_outbound_access_enabled\s*=\s*false')

    def test_default_route_points_at_hub_firewall(self):
        self.assertRegex(self.src, r'address_prefix\s*=\s*"0\.0\.0\.0/0"')
        self.assertRegex(self.src, r'next_hop_type\s*=\s*"VirtualAppliance"')
        self.assertRegex(self.src, r'next_hop_in_ip_address\s*=\s*var\.firewall_private_ip')

    def test_bidirectional_peering_with_gateway_transit(self):
        self.assertEqual(len(re.findall(r'resource "azurerm_virtual_network_peering"', self.src)), 2)
        spoke_side = re.search(r'"spoke_to_hub" \{(.*?)\n\}', self.src, re.S).group(1)
        hub_side = re.search(r'"hub_to_spoke" \{(.*?)\n\}', self.src, re.S).group(1)
        self.assertRegex(spoke_side, r'use_remote_gateways\s*=\s*true')
        self.assertRegex(hub_side, r'allow_gateway_transit\s*=\s*true')
        self.assertRegex(spoke_side, r'allow_forwarded_traffic\s*=\s*true')

    def test_dev_and_prod_spokes_by_default(self):
        variables = read("variables.tf")
        block = re.search(r'variable "spokes" \{.*?default = \{(.*?)\n  \}', variables, re.S).group(1)
        for env in ("dev", "prod"):
            self.assertRegex(block, rf'\b{env}\s*=\s*\{{')

    def test_hub_firewall_ip_wired_from_hub_module(self):
        self.assertRegex(read("main.tf"), r'firewall_private_ip\s*=\s*one\(module\.hub_network\[\*\]\.firewall_private_ip\)')
        self.assertRegex(read("modules/spoke_network/outputs.tf"), r"workload_subnet_prefix")


class BudgetGuardrails(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.src = read("modules/budget/main.tf")

    def test_alert_thresholds_50_80_100_with_one_forecast(self):
        thresholds = sorted(int(t) for t in re.findall(r'threshold\s*=\s*(\d+)', self.src))
        self.assertEqual(thresholds, [50, 80, 100])
        self.assertEqual(len(re.findall(r'threshold_type\s*=\s*"Forecasted"', self.src)), 1)
        self.assertEqual(len(re.findall(r'threshold_type\s*=\s*"Actual"', self.src)), 2)

    def test_monthly_grain(self):
        self.assertRegex(self.src, r'time_grain\s*=\s*"Monthly"')

    def test_both_resource_groups_have_budgets(self):
        main = read("main.tf")
        self.assertEqual(len(re.findall(r'source\s*=\s*"\./modules/budget"', main)), 2)
        self.assertRegex(main, r"one\(module\.observability\[\*\]\.resource_group_id\)")
        self.assertRegex(main, r"one\(module\.hub_network\[\*\]\.resource_group_id\)")


# --- Deploy gating, placeholders and CI safety -------------------------------------

class SafetyGates(unittest.TestCase):
    def test_deploy_disabled_by_default(self):
        self.assertRegex(read("variables.tf"), r'"deploy_enabled"\s*\{[^}]*default\s*=\s*false')

    def test_every_root_module_is_gated(self):
        main = read("main.tf")
        self.assertEqual(main.count("var.deploy_enabled ? 1 : 0"), 7,
                         "management_groups + governance + hub + observability + access_control + 2 budgets must all be gated")
        self.assertEqual(main.count("for_each = var.deploy_enabled ? var.spokes : {}"), 1,
                         "spokes must be gated through for_each")

    def test_placeholder_subscription_and_tenant_ids(self):
        variables = read("variables.tf")
        for var in ("azure_subscription_id", "azure_tenant_id"):
            m = re.search(rf'variable "{var}" \{{[^}}]*default\s*=\s*"([^"]+)"', variables)
            self.assertEqual(m.group(1), "00000000-0000-0000-0000-000000000000", var)

    def test_no_real_guids_anywhere_in_terraform(self):
        """Only all-zero placeholders and the public built-in Contributor role
        definition id may appear as GUIDs."""
        guid = re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b")
        for path in TF.rglob("*.tf"):
            for match in guid.findall(path.read_text()):
                self.assertIn(
                    match,
                    ("00000000-0000-0000-0000-000000000000", "b24988ac-6180-42a0-ab88-20f7382dd24c"),
                    f"unexpected GUID {match} in {path}",
                )

    def test_child_modules_declare_required_providers(self):
        modules = sorted(p.name for p in (TF / "modules").iterdir() if p.is_dir())
        self.assertEqual(
            modules,
            ["access_control", "budget", "governance", "hub_network", "management_groups", "observability", "spoke_network"],
        )
        for module in modules:
            src = read(f"modules/{module}/versions.tf")
            self.assertIn("required_providers", src)
            self.assertRegex(src, r'azurerm\s*=\s*\{')
            self.assertIn("hashicorp/azurerm", src)

    def test_workspace_is_locked_down(self):
        src = read("modules/observability/main.tf")
        self.assertRegex(src, r'local_authentication_enabled\s*=\s*false')

    def test_environment_tfvars_keeps_gate_closed(self):
        tfvars = read("environments/dev.tfvars")
        self.assertRegex(tfvars, r"deploy_enabled\s*=\s*false")

    def test_gitignore_keeps_environment_tfvars_and_blocks_mimosa(self):
        gi = (ROOT / ".gitignore").read_text()
        self.assertIn("!**/environments/*.tfvars", gi)
        self.assertIn(".mimosa/", gi)


class CiSafety(unittest.TestCase):
    """Negative tests: CI must never mutate cloud state."""

    def test_workflow_has_no_apply_destroy_or_login(self):
        wf = (ROOT / ".github/workflows/validate.yml").read_text()
        self.assertNotIn("terraform apply", wf)
        self.assertNotIn("terraform destroy", wf)
        self.assertNotIn("az login", wf)
        self.assertNotIn("id-token: write", wf)

    def test_workflow_permissions_read_only(self):
        wf = (ROOT / ".github/workflows/validate.yml").read_text()
        self.assertIn("contents: read", wf)

    def test_terraform_version_pinned(self):
        wf = (ROOT / ".github/workflows/validate.yml").read_text()
        self.assertRegex(wf, r"terraform_version:\s*'\d+\.\d+\.\d+'")


class Diagram(unittest.TestCase):
    def test_diagram_matches_implemented_architecture(self):
        mmd = (ROOT / "diagrams/architecture.mmd").read_text().lower()
        self.assertIn("flowchart", mmd)
        for needle in ("management group", "policy", "firewall", "bastion", "vpn", "spoke", "deny"):
            self.assertIn(needle, mmd, f"diagram must mention {needle}")


if __name__ == "__main__":
    unittest.main()
