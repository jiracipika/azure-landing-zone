output "status" {
  description = "Guards against mistaking the offline scaffold for a deployment."
  value       = var.deploy_enabled ? "deployment-configured (requires explicit owner approval to apply)" : "offline-scaffold-only"
}

output "root_management_group_id" {
  description = "Lab root management group — the governance assignment target. null unless deploy_enabled."
  value       = one(module.management_groups[*].root_management_group_id)
}

output "governance_assignment_id" {
  description = "Policy assignment inherited by every management group below alz-root. null unless deploy_enabled."
  value       = one(module.governance[*].governance_assignment_id)
}

output "hub_firewall_private_ip" {
  description = "Next hop of every spoke default route. null unless deploy_enabled."
  value       = one(module.hub_network[*].firewall_private_ip)
}

output "log_analytics_workspace_id" {
  description = "Central workspace for firewall and VM diagnostics. null unless deploy_enabled."
  value       = one(module.observability[*].workspace_id)
}

output "spoke_workload_subnets" {
  description = "Workload subnet ids per environment. Empty unless deploy_enabled."
  value       = { for k, v in module.spoke_network : k => v.workload_subnet_id }
}
