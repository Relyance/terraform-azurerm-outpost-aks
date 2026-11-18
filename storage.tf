resource "azurerm_storage_account" "store" {
  for_each                        = local.stores
  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.installation[each.value.installation].name
  location                        = var.installations[each.value.installation].location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  public_network_access           = var.installations[each.value.installation].network_mode == "private" ? "Disabled" : "Enabled"
  min_tls_version                 = "TLS1_2"
  network_rules {
    default_action             = "Deny"
    bypass                     = ["None"]
    ip_rules                   = var.installations[each.value.installation].network_mode == "private" ? [] : [for ip in setunion(var.data_plane_ip_rules, lookup(var.storage_ip_rules, each.key, toset([]))) : trimsuffix(ip, "/32")]
    virtual_network_subnet_ids = [azurerm_subnet.nodes[each.value.installation].id]
  }
  tags = local.names[each.value.installation].tags
}
resource "azurerm_storage_container" "store" {
  for_each              = local.stores
  name                  = each.value.kind
  storage_account_id    = azurerm_storage_account.store[each.key].id
  container_access_type = "private"
}
# Separate containers preserve all direct-route roots and resource addresses.
resource "azurerm_storage_container" "inventory" {
  for_each              = local.inventory_containers
  name                  = each.value.kind
  storage_account_id    = azurerm_storage_account.store["${each.value.installation}/work"].id
  container_access_type = "private"
}
resource "azurerm_key_vault" "credentials" {
  for_each                      = var.installations
  name                          = "kv-${var.name_prefix}-${local.names[each.key].suffix}"
  resource_group_name           = azurerm_resource_group.installation[each.key].name
  location                      = each.value.location
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = each.value.network_mode == "public_allowlist"
  network_acls {
    bypass                     = "None"
    default_action             = "Deny"
    ip_rules                   = each.value.network_mode == "private" ? [] : var.data_plane_ip_rules
    virtual_network_subnet_ids = [azurerm_subnet.nodes[each.key].id]
  }
  tags = local.names[each.key].tags
}
