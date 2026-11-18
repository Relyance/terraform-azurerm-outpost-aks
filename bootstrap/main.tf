resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_storage_account" "state" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  public_network_access           = "Enabled"
  min_tls_version                 = "TLS1_2"
  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
    ip_rules       = [for ip in var.runner_ip_rules : trimsuffix(ip, "/32")]
  }
  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 14 }
    container_delete_retention_policy { days = 14 }
  }
}
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
resource "azurerm_role_assignment" "operator" {
  for_each             = var.operator_object_ids
  scope                = azurerm_storage_container.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}
