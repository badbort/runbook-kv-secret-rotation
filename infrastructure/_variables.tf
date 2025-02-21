# Input variable for Subscription IDs
variable "subscriptions" {
  description = "List of subscriptions with metadata"
  type = list(object({
    SubscriptionId   = string
    RotationDuration = optional(string)
  }))
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}