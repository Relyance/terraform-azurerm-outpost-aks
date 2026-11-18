output "backend" {
  description = "Non-secret backend coordinates. Choose separate keys for bootstrap, regional Azure and install state."
  value = {
    resource_group_name  = azurerm_resource_group.state.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.state.name
    subscription_id      = var.subscription_id
    tenant_id            = var.tenant_id
    use_azuread_auth     = true
  }
}
