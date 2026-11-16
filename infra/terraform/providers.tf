provider "azurerm" {
  # Placeholders satisfy offline validation; set ARM_SUBSCRIPTION_ID /
  # ARM_TENANT_ID or tfvars values before any approved deployment. Tenant-level
  # resources (management groups, policy, RBAC) need the tenant id.
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  features {}
}
