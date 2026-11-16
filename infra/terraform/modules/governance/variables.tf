variable "root_management_group_id" {
  description = "Assignment target and management scope for all definitions."
  type        = string
}

variable "location" {
  description = "Region for the assignment's remediation identity."
  type        = string
}

variable "allowed_locations" {
  type = list(string)
}

variable "allowed_vm_skus" {
  type = list(string)
}

variable "required_tag_environment" {
  type = string
}

variable "required_tag_cost_center" {
  type = string
}

variable "log_analytics_workspace_id" {
  description = "Central workspace consumed by the VM-diagnostics DeployIfNotExists policy. Empty default keeps offline validation inert."
  type        = string
  default     = ""
}
