variable "resource_group_name" {
  type = string
}

variable "workspace_name" {
  type = string
}

variable "location" {
  type = string
}

variable "retention_in_days" {
  description = "Interactive retention (31 days included in ingestion price; 30 is the minimum)."
  type        = number
  default     = 30
}

variable "tags" {
  type = map(string)
}
