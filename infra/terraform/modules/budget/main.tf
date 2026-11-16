# Budget guardrail per resource group. ALERTS ONLY: an Azure budget never
# stops billing — it notifies. Thresholds: 50% and 80% of the monthly actual,
# plus a 100% forecast so the owner learns BEFORE the cap is crossed.
# Ingestion charges (Log Analytics) accrue in the management resource group,
# standing charges (firewall/gateway/bastion) in connectivity — hence a budget
# on each.
resource "azurerm_consumption_budget_resource_group" "this" {
  name              = "budget-${var.resource_group_name}"
  resource_group_id = var.resource_group_id
  amount            = var.amount
  time_grain        = "Monthly"

  time_period {
    start_date = "2026-12-01T00:00:00Z"
  }

  notification {
    enabled        = true
    operator       = "GreaterThan"
    threshold      = 50
    threshold_type = "Actual"
    contact_emails = var.alert_emails
  }

  notification {
    enabled        = true
    operator       = "GreaterThan"
    threshold      = 80
    threshold_type = "Actual"
    contact_emails = var.alert_emails
  }

  notification {
    enabled        = true
    operator       = "GreaterThan"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = var.alert_emails
  }
}
