variable "subscription_ids" {
  description = "Existing subscriptions to place: key = hierarchy node (root|platform|management|connectivity|landing_zones|corp|online|sandbox|decommissioned), value = subscription GUID. Empty = move nothing."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.subscription_ids) : contains(
        ["root", "platform", "management", "connectivity", "landing_zones", "corp", "online", "sandbox", "decommissioned"],
        k
      )
    ])
    error_message = "subscription_ids keys must be existing management group nodes."
  }
}
