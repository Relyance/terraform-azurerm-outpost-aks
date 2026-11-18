resource "azurerm_user_assigned_identity" "cluster" {
  for_each            = var.installations
  name                = "${local.names[each.key].base}-cluster"
  resource_group_name = azurerm_resource_group.installation[each.key].name
  location            = each.value.location
  tags                = local.names[each.key].tags
}
resource "azurerm_user_assigned_identity" "kubelet" {
  for_each            = var.installations
  name                = "${local.names[each.key].base}-kubelet"
  resource_group_name = azurerm_resource_group.installation[each.key].name
  location            = each.value.location
  tags                = local.names[each.key].tags
}
resource "azurerm_user_assigned_identity" "worker" {
  for_each            = var.installations
  name                = "${local.names[each.key].base}-worker"
  resource_group_name = azurerm_resource_group.installation[each.key].name
  location            = each.value.location
  tags                = local.names[each.key].tags
}
resource "azurerm_user_assigned_identity" "reader" {
  for_each            = var.installations
  name                = "${local.names[each.key].base}-reader"
  resource_group_name = azurerm_resource_group.installation[each.key].name
  location            = each.value.location
  tags                = local.names[each.key].tags
}
resource "azurerm_role_assignment" "cluster_network" {
  for_each             = var.installations
  scope                = azurerm_subnet.nodes[each.key].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "kubelet_operator" {
  for_each             = var.installations
  scope                = azurerm_user_assigned_identity.kubelet[each.key].id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.cluster[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "image_reader" {
  for_each             = var.installations
  scope                = azurerm_container_registry.images[each.key].id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.kubelet[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "operator" {
  for_each             = local.operators
  scope                = azurerm_kubernetes_cluster.installation[each.value.installation].id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value.object_id
}
resource "azurerm_federated_identity_credential" "worker" {
  for_each                  = var.installations
  name                      = "aks-worker"
  user_assigned_identity_id = azurerm_user_assigned_identity.worker[each.key].id
  issuer                    = azurerm_kubernetes_cluster.installation[each.key].oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:${each.value.namespace}:relyance"
}
resource "azurerm_federated_identity_credential" "reader" {
  for_each                  = var.installations
  name                      = "google-hosted-reader"
  user_assigned_identity_id = azurerm_user_assigned_identity.reader[each.key].id
  issuer                    = "https://accounts.google.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = var.hosted_reader_google_subject
}
resource "azurerm_role_definition" "findings_writer" {
  for_each          = var.installations
  name              = "${local.names[each.key].base}-findings-write"
  scope             = azurerm_resource_group.installation[each.key].id
  assignable_scopes = [azurerm_resource_group.installation[each.key].id]
  description       = "Findings read/write/add grant; no delete grant. Not an explicit deny against HNS ACLs or inherited roles."
  permissions {
    actions = ["Microsoft.Storage/storageAccounts/blobServices/containers/read"]
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ]
  }
}
resource "azurerm_role_assignment" "work" {
  for_each             = var.installations
  scope                = azurerm_storage_container.store["${each.key}/work"].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.worker[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "findings_writer" {
  for_each           = var.installations
  scope              = azurerm_storage_container.store["${each.key}/findings"].id
  role_definition_id = azurerm_role_definition.findings_writer[each.key].role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.worker[each.key].principal_id
  principal_type     = "ServicePrincipal"
}
resource "azurerm_role_assignment" "findings_reader" {
  for_each             = var.installations
  scope                = azurerm_storage_container.store["${each.key}/findings"].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.reader[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "vault_reader" {
  for_each             = var.installations
  scope                = azurerm_key_vault.credentials[each.key].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.worker[each.key].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_definition" "inventory_writer" {
  for_each          = local.inventory_installations
  name              = "${local.names[each.key].base}-inventory-write"
  scope             = azurerm_resource_group.installation[each.key].id
  assignable_scopes = [azurerm_resource_group.installation[each.key].id]
  description       = "Inventory read/write/add only; effective HNS ACLs and inherited grants require separate audit."
  permissions {
    actions = ["Microsoft.Storage/storageAccounts/blobServices/containers/read"]
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ]
  }
}
resource "azurerm_role_assignment" "inventory_writer" {
  for_each           = local.inventory_installations
  scope              = azurerm_storage_container.inventory["${each.key}/inventory"].id
  role_definition_id = azurerm_role_definition.inventory_writer[each.key].role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.worker[each.key].principal_id
  principal_type     = "ServicePrincipal"
}
resource "azurerm_role_assignment" "outbox_writer" {
  for_each             = local.inventory_installations
  scope                = azurerm_storage_container.inventory["${each.key}/outbox"].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.worker[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
resource "azurerm_role_assignment" "inventory_reader" {
  for_each             = local.inventory_installations
  scope                = azurerm_storage_container.inventory["${each.key}/inventory"].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.reader[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
