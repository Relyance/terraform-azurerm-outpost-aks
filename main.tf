locals {
  names = { for key, v in var.installations : key => {
    base   = "${var.name_prefix}-${v.deployment_id}"
    suffix = substr(sha256("${var.subscription_id}/${var.name_prefix}/${v.deployment_id}"), 0, 10)
    tags   = merge(var.tags, { "inhost-deployment" = v.deployment_id, "inhost-location" = v.location, "managed-by" = "terraform" })
  } }
  private_installations   = { for key, v in var.installations : key => v if v.network_mode == "private" }
  inventory_installations = { for key, v in var.installations : key => v if v.inventory_enabled }
  inventory_containers = merge([for key, v in local.inventory_installations : {
    for kind in ["inventory", "outbox"] : "${key}/${kind}" => { installation = key, kind = kind }
  }]...)
  stores = merge([for key, v in var.installations : {
    for kind in ["work", "findings"] : "${key}/${kind}" => {
      installation = key
      kind         = kind
      name         = "${var.name_prefix}${local.names[key].suffix}${kind == "work" ? "wrk" : "fnd"}"
    }
  }]...)
  operators = merge([for key, v in var.installations : {
    for id in var.operator_object_ids : "${key}/${id}" => { installation = key, object_id = id }
  }]...)
}

resource "azurerm_resource_group" "installation" {
  for_each = var.installations
  name     = local.names[each.key].base
  location = each.value.location
  tags     = local.names[each.key].tags
}

resource "azurerm_container_registry" "images" {
  for_each            = var.installations
  name                = "${var.name_prefix}${local.names[each.key].suffix}acr"
  resource_group_name = azurerm_resource_group.installation[each.key].name
  location            = each.value.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.names[each.key].tags
}
