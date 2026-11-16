"""Offline Azure Policy simulator: parses the REAL policy definitions out of
modules/governance and replays allow/deny/audit decisions against sample
resources — in the spirit of the two-tier repo's NSG simulator.

Why heredocs: policy rules in modules/governance/policy-definitions.tf are
written as strict-JSON heredocs (not jsonencode), so this module can extract
the EXACT rule Terraform would submit and evaluate it with Python's json
module. Any drift between parser and HCL raises immediately.
"""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
GOV = ROOT / "infra" / "terraform" / "modules" / "governance"

CONTRIBUTOR_ROLE_ID = "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"


def _files():
    return sorted(GOV.glob("*.tf"))


def _heredoc(tagged_block: str) -> str:
    """Extract the strict-JSON body of the first heredoc assigned in the block."""
    m = re.search(r'= <<-([A-Z]+)\n(.*?)\n\s*\1(?:\s|$)', tagged_block, re.S)
    if not m:
        raise ValueError("no heredoc found — parser and HCL drifted")
    return m.group(2)


def _blocks(text: str, resource_type: str):
    for m in re.finditer(
        rf'resource "{resource_type}" "(\w+)" \{{', text
    ):
        # Match braces to find the end of the block.
        depth, start = 1, m.end()
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    yield m.group(1), text[m.start():i + 1]
                    break


def load_definitions() -> dict:
    """Every azurerm_policy_definition: {key: {name, mode, rule, parameters}}."""
    defs = {}
    for path in _files():
        for key, block in _blocks(path.read_text(), "azurerm_policy_definition"):
            defs[key] = {
                "key": key,
                "name": re.search(r'^\s{2}name\s+= "([^"]+)"', block, re.M).group(1),
                "mode": re.search(r'^\s{2}mode\s+= "([^"]+)"', block, re.M).group(1),
                "rule": json.loads(_heredoc(block)),
                "parameters": json.loads(re.search(
                    r'parameters = <<-PARAMS\n(.*?)\n\s*PARAMS', block, re.S).group(1)),
            }
    if not defs:
        raise ValueError("no policy definitions parsed — parser and HCL drifted")
    return defs


def load_initiative() -> dict:
    """The azurerm_policy_set_definition: references with parameter mappings."""
    set_def = None
    for path in _files():
        for key, block in _blocks(path.read_text(), "azurerm_policy_set_definition"):
            refs = []
            for ref in re.finditer(
                r'policy_definition_reference \{(.*?)\n  \}', block, re.S
            ):
                body = ref.group(1)
                def_id = re.search(
                    r'policy_definition_id = azurerm_policy_definition\.(\w+)\.id', body)
                ref_id = re.search(r'reference_id\s+= "([^"]+)"', body)
                values = re.search(
                    r'parameter_values = <<-VALUES\n(.*?)\n\s*VALUES', body, re.S)
                refs.append({
                    "definition_key": def_id.group(1) if def_id else None,
                    "reference_id": ref_id.group(1) if ref_id else None,
                    "parameter_values": json.loads(values.group(1)) if values else {},
                })
            set_def = {
                "key": key,
                "references": refs,
                "parameters": json.loads(re.search(
                    r'parameters = <<-PARAMS\n(.*?)\n\s*PARAMS', block, re.S).group(1)),
            }
    if set_def is None:
        raise ValueError("no policy set definition parsed — parser and HCL drifted")
    return set_def


def load_assignment() -> dict:
    """The management-group policy assignment: target var, enforce flag, identity."""
    for path in _files():
        for _, block in _blocks(path.read_text(), "azurerm_management_group_policy_assignment"):
            enforce = re.search(r'^\s{2}enforce\s+= (true|false)', block, re.M)
            mg = re.search(r'^\s{2}management_group_id\s+= (\S+)', block, re.M)
            identity = re.search(r'type\s+= "(\w+)"', block)
            return {
                "management_group_id": mg.group(1),
                "enforce": enforce.group(1) == "true" if enforce else None,
                "identity_type": identity.group(1) if identity else None,
            }
    raise ValueError("no policy assignment parsed — parser and HCL drifted")


# --- Evaluation ----------------------------------------------------------------

def resolve(expr, params):
    """Resolve policy parameter expressions: [parameters('x')] and the
    concat('tags[', parameters('tagName'), ']') field builder."""
    if not isinstance(expr, str):
        return expr
    m = re.fullmatch(r"\[parameters\('(\w+)'\)\]", expr)
    if m:
        if m.group(1) not in params:
            raise ValueError(f"unresolved initiative parameter '{m.group(1)}'")
        return params[m.group(1)]
    m = re.fullmatch(r"\[concat\((.+)\)\]", expr)
    if m:
        parts = [p.strip() for p in m.group(1).split(",")]
        out = ""
        for p in parts:
            lit = re.fullmatch(r"'([^']*)'", p)
            out += resolve(f"[{p}]", params) if not lit else lit.group(1)
        return out
    return expr


def field_value(resource: dict, field: str):
    """Field lookup on the sample resource: location, type, tags[x],
    Microsoft.Compute/virtualMachines/sku.name, properties.*."""
    if field == "location":
        return resource.get("location")
    if field == "type":
        return resource.get("type")
    m = re.fullmatch(r"tags\[(.+)\]", field)
    if m:
        return resource.get("tags", {}).get(m.group(1))
    if field == "Microsoft.Compute/virtualMachines/sku.name":
        return resource.get("sku", {}).get("name")
    m = re.fullmatch(r"properties\.(.+)", field)
    if m:
        return resource.get("properties", {}).get(m.group(1))
    raise ValueError(f"simulator does not know field '{field}' — extend it")


def eval_condition(node, resource: dict, params: dict) -> bool:
    if "not" in node:
        return not eval_condition(node["not"], resource, params)
    if "allOf" in node:
        return all(eval_condition(c, resource, params) for c in node["allOf"])
    if "anyOf" in node:
        return any(eval_condition(c, resource, params) for c in node["anyOf"])
    if "field" not in node:
        raise ValueError(f"unsupported condition node: {sorted(node)}")
    field = resolve(node["field"], params) if isinstance(node["field"], str) and node["field"].startswith("[") else node["field"]
    if "exists" in node:
        actual = field_value(resource, field) is not None
        expected = str(node["exists"]).lower() == "true"
        return actual == expected
    if "in" in node:
        return field_value(resource, field) in resolve(node["in"], params)
    if "notIn" in node:
        return field_value(resource, field) not in resolve(node["notIn"], params)
    if "equals" in node:
        return field_value(resource, field) == resolve(node["equals"], params)
    if "notEquals" in node:
        return field_value(resource, field) != resolve(node["notEquals"], params)
    raise ValueError(f"unsupported operator on field '{field}': {sorted(node)}")


def evaluate_definition(definition: dict, resource: dict, params: dict):
    """One policy against one resource: returns the effect string when the
    policy fires (deny/audit/deployIfNotExists), None when compliant/absent."""
    rule = definition["rule"]
    if not eval_condition(rule["if"], resource, params):
        return None
    then = rule["then"]
    effect = then["effect"]
    if effect.lower() == "deployifnotexists":
        related = resource.get("diagnosticSettings", [])
        cond = then["details"]["existenceCondition"]
        if any(eval_condition(cond, {"properties": r.get("properties", {})}, params) for r in related):
            return None  # a matching diagnostic setting already exists
        return effect
    return effect


def evaluate_initiative(resource: dict, assignment_params: dict) -> list:
    """The whole baseline against one resource: [(reference_id, effect), ...]
    for every policy that fires (empty list = fully compliant)."""
    definitions = load_definitions()
    initiative = load_initiative()
    fired = []
    for ref in initiative["references"]:
        definition = definitions[ref["definition_key"]]
        params = {}
        for pname, spec in ref["parameter_values"].items():
            params[pname] = resolve(spec["value"], assignment_params)
        effect = evaluate_definition(definition, resource, params)
        if effect:
            fired.append((ref["reference_id"], effect))
    return fired


def default_assignment_params() -> dict:
    """Initiative parameter values as the repo's root variables default them
    (parsed from infra/terraform/variables.tf)."""
    text = (ROOT / "infra" / "terraform" / "variables.tf").read_text()

    def var_list(name):
        m = re.search(rf'variable "{name}" \{{.*?default\s+= \[(.*?)\]', text, re.S)
        return re.findall(r'"([^"]+)"', m.group(1))

    def var_str(name):
        m = re.search(rf'variable "{name}" \{{.*?default\s+= "([^"]+)"', text, re.S)
        return m.group(1)

    return {
        "allowedLocations": var_list("allowed_locations"),
        "allowedVmSkus": var_list("allowed_vm_skus"),
        "requiredTagEnvironment": var_str("required_tag_environment"),
        "requiredTagCostCenter": var_str("required_tag_cost_center"),
        "workspaceResourceId": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-alz-management/providers/Microsoft.OperationalInsights/workspaces/log-alz-management",
    }
