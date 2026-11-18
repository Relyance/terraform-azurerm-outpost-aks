variable "subscription_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "Use the exact commercial Azure subscription UUID."
  }
}
variable "tenant_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "Use the exact Azure tenant UUID."
  }
}
variable "name_prefix" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,7}$", var.name_prefix))
    error_message = "name_prefix must be 3-8 lowercase alphanumeric characters, starting with a letter."
  }
}
variable "operator_object_ids" {
  type = set(string)
  validation {
    condition     = length(var.operator_object_ids) > 0 && alltrue([for id in var.operator_object_ids : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))])
    error_message = "Explicit operator Entra object IDs are required for cluster administration."
  }
}
variable "management_api_cidrs" {
  type = set(string)
  validation {
    condition     = length(var.management_api_cidrs) > 0 && alltrue([for cidr in var.management_api_cidrs : can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) >= 2, false)])
    error_message = "Explicit bounded IPv4 CIDRs for the AKS management API are required."
  }
}
variable "data_plane_ip_rules" {
  description = "Public operator and stable hosted-reader IPv4/CIDR egress. Required in public_allowlist mode; no implicit cloud-service bypass."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for cidr in var.data_plane_ip_rules : can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) >= 2, false)])
    error_message = "Data-plane IP rules must be explicit bounded IPv4 CIDRs."
  }
}
variable "storage_ip_rules" {
  description = "Additional IPv4 CIDRs for a specific installation and store (work or findings). These do not grant access to other stores or Key Vault."
  type        = map(set(string))
  default     = {}
  validation {
    condition = alltrue([for key, ips in var.storage_ip_rules :
      contains(flatten([for name in keys(var.installations) : ["${name}/work", "${name}/findings"]]), key) &&
      alltrue([for ip in ips : can(cidrnetmask(ip)) && try(tonumber(split("/", ip)[1]) >= 2, false)])
    ])
    error_message = "Use a known installation/store key and explicit bounded IPv4 CIDRs."
  }
}
variable "hosted_reader_google_subject" {
  description = "Numeric unique ID of the ACTUAL hosted transfer runtime GSA, supplied by the trusted hosted operator. Never a GSA email or CI identity."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{10,24}$", var.hosted_reader_google_subject))
    error_message = "The hosted reader subject must be its numeric Google runtime subject."
  }
}
variable "installations" {
  type = map(object({
    deployment_id      = string
    location           = string
    namespace          = string
    vnet_cidr          = string
    kubernetes_version = string
    route_revision     = optional(number, 1)
    pricing_tier       = optional(string, "Standard")
    runtime_profile    = optional(string, "standard")
    inventory_enabled  = optional(bool, false)
    network_mode       = optional(string, "public_allowlist")
    scaling_mode       = optional(string, "cluster_autoscaler")
    system_node_count  = optional(number, 2)
    system_vm_size     = optional(string, "Standard_D4s_v5")
    workload_vm_size   = optional(string, "Standard_D8s_v5")
    workload_max_nodes = optional(number, 3)
    nap_cpu_limit      = optional(number, 32)
  }))
  validation {
    condition = length(var.installations) > 0 && alltrue([for v in var.installations :
      can(regex("^[a-z][a-z0-9-]{0,19}$", v.deployment_id)) &&
      can(regex("^[a-z][a-z0-9]{1,31}$", v.location)) &&
      can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", v.namespace)) &&
      can(regex("^10\\.[0-9]{1,3}\\.0\\.0/16$", v.vnet_cidr)) && can(cidrnetmask(v.vnet_cidr)) &&
      can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", v.kubernetes_version)) &&
      contains(["public_allowlist", "private"], v.network_mode) &&
      contains(["cluster_autoscaler", "nap"], v.scaling_mode) &&
      contains(["Free", "Standard"], v.pricing_tier) &&
      contains(["standard", "small_sandbox"], v.runtime_profile) &&
      v.route_revision >= 1 && floor(v.route_revision) == v.route_revision &&
      v.system_node_count >= 2 && v.system_node_count <= 5 && floor(v.system_node_count) == v.system_node_count &&
      v.workload_max_nodes >= 1 && v.workload_max_nodes <= 100 && floor(v.workload_max_nodes) == v.workload_max_nodes &&
      v.nap_cpu_limit >= 8 && v.nap_cpu_limit <= 256 && floor(v.nap_cpu_limit) == v.nap_cpu_limit
    ])
    error_message = "Each installation needs canonical authority, a supported-version input, a distinct 10.x.0.0/16 VNet, bounded capacity and a supported network/scaling mode."
  }
  validation {
    condition = (
      length(distinct([for v in var.installations : v.deployment_id])) == length(var.installations) &&
      length(distinct([for v in var.installations : v.vnet_cidr])) == length(var.installations)
    )
    error_message = "Installation deployment IDs and VNet ranges must be distinct."
  }
  validation {
    condition = alltrue([for v in var.installations : v.runtime_profile != "small_sandbox" || (
      !v.inventory_enabled && length(var.installations) == 1 && v.pricing_tier == "Free" &&
      v.scaling_mode == "cluster_autoscaler" && v.network_mode == "public_allowlist" &&
      v.system_node_count == 2 && v.system_vm_size == "Standard_D4s_v5" &&
      v.workload_vm_size == "Standard_E4s_v5" && v.workload_max_nodes == 1
    )])
    error_message = "small_sandbox does not support inventory; it requires one Free-tier public-allowlisted CAS installation, two D4s_v5 system nodes and at most one E4s_v5 workload node."
  }
  validation {
    condition     = alltrue([for v in var.installations : v.network_mode != "public_allowlist" || length(var.data_plane_ip_rules) > 0])
    error_message = "Public sandbox storage/vault access requires explicit data_plane_ip_rules including stable hosted-reader egress."
  }
}
variable "source_blob_reader_grants" {
  description = "Explicit existing source container ARM IDs and the regional installation whose AKS workload may read them. Prefix restrictions remain application policy; these grants never include writes or hosted readers."
  type = map(object({
    installation          = string
    container_resource_id = string
  }))
  default = {}
  validation {
    condition = alltrue([for grant in var.source_blob_reader_grants :
      contains(keys(var.installations), grant.installation) &&
      can(regex("^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/[a-z0-9]{3,24}/blobServices/default/containers/[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", grant.container_resource_id))
    ])
    error_message = "Each source grant must name an existing installation and an exact Blob container ARM ID; subscription, resource-group and storage-account scopes are not accepted."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
