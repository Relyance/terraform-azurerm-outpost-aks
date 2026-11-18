variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "storage_account_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "State storage needs a globally unique 3-24 character lowercase alphanumeric name."
  }
}
variable "operator_object_ids" {
  type = set(string)
  validation {
    condition     = length(var.operator_object_ids) > 0 && alltrue([for id in var.operator_object_ids : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "At least one explicit operator object ID is required for state access."
  }
}
variable "runner_ip_rules" {
  type = set(string)
  validation {
    condition     = length(var.runner_ip_rules) > 0 && alltrue([for ip in var.runner_ip_rules : can(cidrnetmask(ip)) && try(tonumber(split("/", ip)[1]) >= 2, false)])
    error_message = "Only explicit bounded runner IPv4 CIDRs may access state."
  }
}
