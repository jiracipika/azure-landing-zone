variable "resource_group_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "amount" {
  description = "Monthly budget amount. Alerts only — does not cap spending."
  type        = number
}

variable "alert_emails" {
  description = "Recipients of the 50/80/100 percent alerts."
  type        = list(string)
  default     = []
}
