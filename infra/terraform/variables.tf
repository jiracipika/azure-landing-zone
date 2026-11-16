variable "deploy_enabled" {
  type = bool
  default = false
  description = "Approval guard. No Azure resources are currently defined."
}
variable "location" {
  type = string
  default = "canadacentral"
}
