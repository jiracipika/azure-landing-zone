variable "root_management_group_id" {
  description = "Storage scope of the custom role definition."
  type        = string
}

variable "corp_management_group_id" {
  description = "The ONLY assignable scope of the role and its assignment."
  type        = string
}

variable "principal_id" {
  description = "Object id of the workload team principal. REQUIRED before enabling deploy_enabled; empty default keeps the offline scaffold inert."
  type        = string
  default     = ""
}
