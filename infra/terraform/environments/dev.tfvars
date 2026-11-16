# Offline-safe defaults: the deploy gate stays closed. To prepare a real
# deployment (owner approval required first), set deploy_enabled = true,
# provide azure_subscription_id / azure_tenant_id, subscription_ids placement
# and spoke_operator_principal_id via -var-file / environment, then review
# terraform plan BEFORE any apply.
deploy_enabled      = false
location            = "canadacentral"
allowed_locations   = ["canadacentral", "canadaeast", "global"]
allowed_vm_skus     = ["Standard_B1s", "Standard_B2s", "Standard_B2ms", "Standard_D2s_v5"]
vpn_gateway_sku     = "VpnGw1"
bastion_sku         = "Basic"
budget_amount       = 10
budget_alert_emails = []
subscription_ids    = {}
