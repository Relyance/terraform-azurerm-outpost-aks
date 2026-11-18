resource "azurerm_virtual_network" "installation" {
  for_each            = var.installations
  name                = "${local.names[each.key].base}-vnet"
  resource_group_name = azurerm_resource_group.installation[each.key].name
  location            = each.value.location
  address_space       = [each.value.vnet_cidr]
  tags                = local.names[each.key].tags
}
resource "azurerm_subnet" "nodes" {
  for_each             = var.installations
  name                 = "nodes"
  resource_group_name  = azurerm_resource_group.installation[each.key].name
  virtual_network_name = azurerm_virtual_network.installation[each.key].name
  address_prefixes     = [cidrsubnet(each.value.vnet_cidr, 4, 0)]
  service_endpoint { service = "Microsoft.Storage" }
  service_endpoint { service = "Microsoft.KeyVault" }
}
resource "azurerm_subnet" "endpoints" {
  for_each             = local.private_installations
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.installation[each.key].name
  virtual_network_name = azurerm_virtual_network.installation[each.key].name
  address_prefixes     = [cidrsubnet(each.value.vnet_cidr, 4, 1)]
}
locals {
  endpoint_stores = merge([for key, store in local.stores : {
    for service in ["blob", "dfs"] : "${key}/${service}" => merge(store, { store_key = key, service = service })
  } if contains(keys(local.private_installations), store.installation)]...)
  private_zones = merge([for key, v in local.private_installations : {
    for service, name in { blob = "privatelink.blob.core.windows.net", dfs = "privatelink.dfs.core.windows.net", vault = "privatelink.vaultcore.azure.net" } :
    "${key}/${service}" => { installation = key, service = service, name = name }
  }]...)
}
resource "azurerm_private_dns_zone" "service" {
  for_each            = local.private_zones
  name                = each.value.name
  resource_group_name = azurerm_resource_group.installation[each.value.installation].name
}
resource "azurerm_private_dns_zone_virtual_network_link" "service" {
  for_each             = local.private_zones
  name                 = "inhost-${each.value.service}"
  private_dns_zone_id  = azurerm_private_dns_zone.service[each.key].id
  virtual_network_id   = azurerm_virtual_network.installation[each.value.installation].id
  registration_enabled = false
}
resource "azurerm_private_endpoint" "storage" {
  for_each            = local.endpoint_stores
  name                = "${each.value.kind}-${each.value.service}"
  resource_group_name = azurerm_resource_group.installation[each.value.installation].name
  location            = var.installations[each.value.installation].location
  subnet_id           = azurerm_subnet.endpoints[each.value.installation].id
  private_service_connection {
    name                           = "${each.value.kind}-${each.value.service}"
    private_connection_resource_id = azurerm_storage_account.store[each.value.store_key].id
    is_manual_connection           = false
    subresource_names              = [each.value.service]
  }
  private_dns_zone_group {
    name                 = "storage"
    private_dns_zone_ids = [azurerm_private_dns_zone.service["${each.value.installation}/${each.value.service}"].id]
  }
}
resource "azurerm_private_endpoint" "vault" {
  for_each            = local.private_installations
  name                = "vault"
  resource_group_name = azurerm_resource_group.installation[each.key].name
  location            = each.value.location
  subnet_id           = azurerm_subnet.endpoints[each.key].id
  private_service_connection {
    name                           = "vault"
    private_connection_resource_id = azurerm_key_vault.credentials[each.key].id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
  private_dns_zone_group {
    name                 = "vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.service["${each.key}/vault"].id]
  }
}
