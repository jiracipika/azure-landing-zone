# Governance baseline initiative: one set definition bundling every custom
# definition above, assigned once at the lab root (see policy-assignment.tf).
resource "azurerm_policy_set_definition" "governance_baseline" {
  name                = "alz-governance-baseline"
  policy_type         = "Custom"
  display_name        = "ALZ governance baseline"
  description         = "Locations, VM SKUs, mandatory tags and VM diagnostics for the whole management group hierarchy."
  management_group_id = var.root_management_group_id

  metadata = jsonencode({
    category = "Landing Zone"
  })

  parameters = <<-PARAMS
    {
      "allowedLocations": {
        "type": "Array",
        "metadata": {
          "displayName": "Allowed locations",
          "description": "Locations permitted for every resource in the hierarchy."
        }
      },
      "allowedVmSkus": {
        "type": "Array",
        "metadata": {
          "displayName": "Allowed VM SKUs",
          "description": "Low-cost SKUs permitted for virtual machines."
        }
      },
      "requiredTagEnvironment": {
        "type": "String",
        "metadata": {
          "displayName": "Environment tag name",
          "description": "Tag key identifying environment (dev/prod)."
        }
      },
      "requiredTagCostCenter": {
        "type": "String",
        "metadata": {
          "displayName": "Cost center tag name",
          "description": "Tag key identifying the owning cost center."
        }
      },
      "workspaceResourceId": {
        "type": "String",
        "metadata": {
          "displayName": "Central Log Analytics workspace id",
          "description": "Workspace that receives VM diagnostics via DeployIfNotExists."
        }
      }
    }
  PARAMS

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.allowed_locations.id
    reference_id         = "allowed_locations"

    parameter_values = <<-VALUES
      {
        "listOfAllowedLocations": {
          "value": "[parameters('allowedLocations')]"
        }
      }
    VALUES
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.allowed_vm_skus.id
    reference_id         = "allowed_vm_skus"

    parameter_values = <<-VALUES
      {
        "listOfAllowedSkus": {
          "value": "[parameters('allowedVmSkus')]"
        }
      }
    VALUES
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_tag.id
    reference_id         = "require_tag_environment"

    parameter_values = <<-VALUES
      {
        "tagName": {
          "value": "[parameters('requiredTagEnvironment')]"
        }
      }
    VALUES
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.require_tag.id
    reference_id         = "require_tag_cost_center"

    parameter_values = <<-VALUES
      {
        "tagName": {
          "value": "[parameters('requiredTagCostCenter')]"
        }
      }
    VALUES
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.deploy_vm_diagnostics.id
    reference_id         = "deploy_vm_diagnostics"

    parameter_values = <<-VALUES
      {
        "workspaceId": {
          "value": "[parameters('workspaceResourceId')]"
        }
      }
    VALUES
  }
}
