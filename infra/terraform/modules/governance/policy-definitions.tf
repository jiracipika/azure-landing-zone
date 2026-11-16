# Custom Azure Policy definitions for the governance baseline. Policy rules and
# parameters are written as strict JSON heredocs (not jsonencode) so the offline
# simulator in tests/policy_simulator.py can parse the EXACT rules Terraform
# would submit and replay allow/deny decisions against sample resources.

# --- 1. Allowed locations (effect: Deny) --------------------------------------
resource "azurerm_policy_definition" "allowed_locations" {
  name                = "alz-allowed-locations"
  policy_type         = "Custom"
  mode                = "All"
  display_name        = "ALZ: Allowed locations"
  description         = "Restricts resource creation to approved Azure regions. Assigned at the lab root so every management group below inherits it."
  management_group_id = var.root_management_group_id

  policy_rule = <<-RULE
    {
      "if": {
        "not": {
          "field": "location",
          "in": "[parameters('listOfAllowedLocations')]"
        }
      },
      "then": {
        "effect": "deny"
      }
    }
  RULE

  parameters = <<-PARAMS
    {
      "listOfAllowedLocations": {
        "type": "Array",
        "metadata": {
          "displayName": "Allowed locations",
          "description": "The list of locations resources may be created in.",
          "strongType": "location"
        }
      }
    }
  PARAMS
}

# --- 2. Allowed VM SKUs (effect: Deny) ----------------------------------------
resource "azurerm_policy_definition" "allowed_vm_skus" {
  name                = "alz-allowed-vm-skus"
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = "ALZ: Allowed virtual machine SKUs"
  description         = "Blocks expensive/GPU SKUs: only the low-cost B/D-series lab list may be deployed."
  management_group_id = var.root_management_group_id

  policy_rule = <<-RULE
    {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Compute/virtualMachines"
          },
          {
            "not": {
              "field": "Microsoft.Compute/virtualMachines/sku.name",
              "in": "[parameters('listOfAllowedSkus')]"
            }
          }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
  RULE

  parameters = <<-PARAMS
    {
      "listOfAllowedSkus": {
        "type": "Array",
        "metadata": {
          "displayName": "Allowed VM SKUs",
          "description": "The list of virtual machine SKUs that can be deployed."
        }
      }
    }
  PARAMS
}

# --- 3. Require tag (effect: Audit) -------------------------------------------
# Standard built-in pattern: field built with concat() from the tagName
# parameter, existence check falsified for missing tags.
resource "azurerm_policy_definition" "require_tag" {
  name                = "alz-require-tag"
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = "ALZ: Require a tag on resources"
  description         = "Audits resources that lack a mandatory governance tag. Referenced twice in the initiative (environment, costCenter)."
  management_group_id = var.root_management_group_id

  policy_rule = <<-RULE
    {
      "if": {
        "field": "[concat('tags[', parameters('tagName'), ']')]",
        "exists": "false"
      },
      "then": {
        "effect": "audit"
      }
    }
  RULE

  parameters = <<-PARAMS
    {
      "tagName": {
        "type": "String",
        "metadata": {
          "displayName": "Tag name",
          "description": "Name of the required tag, e.g. environment or costCenter."
        }
      }
    }
  PARAMS
}

# --- 4. Deploy VM diagnostics (effect: DeployIfNotExists) ---------------------
# Remediation-style policy: if a VM has no diagnostic setting pointing at the
# central workspace, policy deploys one. Requires a managed identity on the
# assignment (granted Contributor via roleDefinitionIds) — the reason the
# assignment below declares identity { type = "SystemAssigned" }.
resource "azurerm_policy_definition" "deploy_vm_diagnostics" {
  name                = "alz-deploy-vm-diagnostics"
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = "ALZ: Deploy VM diagnostics to the central workspace"
  description         = "DeployIfNotExists: creates a diagnosticSettings resource sending VM metrics to the platform Log Analytics workspace."
  management_group_id = var.root_management_group_id

  policy_rule = <<-RULE
    {
      "if": {
        "field": "type",
        "equals": "Microsoft.Compute/virtualMachines"
      },
      "then": {
        "effect": "deployIfNotExists",
        "details": {
          "type": "Microsoft.Insights/diagnosticSettings",
          "roleDefinitionIds": [
            "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
          ],
          "existenceCondition": {
            "allOf": [
              {
                "field": "properties.workspaceId",
                "equals": "[parameters('workspaceId')]"
              }
            ]
          },
          "deployment": {
            "properties": {
              "mode": "incremental",
              "parameters": {
                "workspaceId": {
                  "value": "[parameters('workspaceId')]"
                }
              },
              "template": {
                "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                "contentVersion": "1.0.0.0",
                "parameters": {
                  "workspaceId": {
                    "type": "String"
                  }
                },
                "variables": {},
                "resources": [
                  {
                    "type": "Microsoft.Compute/virtualMachines/providers/diagnosticSettings",
                    "apiVersion": "2021-05-01-preview",
                    "name": "[concat(field('name'), '/Microsoft.Insights/alz-workspace')]",
                    "properties": {
                      "workspaceId": "[parameters('workspaceId')]",
                      "logs": [],
                      "metrics": [
                        {
                          "category": "AllMetrics",
                          "enabled": true,
                          "timeGrain": "PT1M"
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      }
    }
  RULE

  parameters = <<-PARAMS
    {
      "workspaceId": {
        "type": "String",
        "metadata": {
          "displayName": "Log Analytics workspace resource id",
          "description": "Resource id of the central Log Analytics workspace (e.g. from modules/observability).",
          "strongType": "omsWorkspace"
        }
      }
    }
  PARAMS
}
