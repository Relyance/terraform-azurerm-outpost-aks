resource "azurerm_role_assignment" "source_blob_reader" {
  for_each             = var.source_blob_reader_grants
  scope                = each.value.container_resource_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.worker[each.value.installation].principal_id
  principal_type       = "ServicePrincipal"
}
