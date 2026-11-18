output "installations" {
  description = "Provisioning facts only. Not an accepted control-plane registration, network reachability proof or permission audit."
  value = { for key, v in var.installations : key => merge({
    schema_version               = 1
    runtime_profile              = v.runtime_profile
    deployment_id                = v.deployment_id
    route_revision               = v.route_revision
    azure_tenant_id              = var.tenant_id
    azure_subscription_id        = var.subscription_id
    azure_location               = v.location
    namespace                    = v.namespace
    workload_client_id           = azurerm_user_assigned_identity.worker[key].client_id
    reader_client_id             = azurerm_user_assigned_identity.reader[key].client_id
    hosted_reader_google_subject = var.hosted_reader_google_subject
    work_uri                     = "abfss://work@${azurerm_storage_account.store["${key}/work"].name}.dfs.core.windows.net"
    findings_uri                 = "abfss://findings@${azurerm_storage_account.store["${key}/findings"].name}.dfs.core.windows.net"
    key_vault_uri                = trimsuffix(azurerm_key_vault.credentials[key].vault_uri, "/")
    storage_authorities = { for kind in ["work", "findings"] : azurerm_storage_account.store["${key}/${kind}"].name => {
      resource_id = azurerm_storage_account.store["${key}/${kind}"].id
      location    = v.location
    } }
    key_vault_authority = { resource_id = azurerm_key_vault.credentials[key].id, location = v.location }
    cluster = {
      name            = azurerm_kubernetes_cluster.installation[key].name
      id              = azurerm_kubernetes_cluster.installation[key].id
      resource_group  = azurerm_resource_group.installation[key].name
      oidc_issuer_url = azurerm_kubernetes_cluster.installation[key].oidc_issuer_url
    }
    image_registry                               = azurerm_container_registry.images[key].login_server
    storage_class                                = "managed-csi"
    network_mode                                 = v.network_mode
    scaling_mode                                 = v.scaling_mode
    node_subnet_id                               = azurerm_subnet.nodes[key].id
    nap_cpu_limit                                = v.nap_cpu_limit
    workload_node_selector                       = { "inhost-node-role" = "workload", "inhost-deployment" = v.deployment_id, "kubernetes.io/arch" = "amd64" }
    }, v.inventory_enabled ? { inventory_enabled = true } : {}, v.inventory_enabled ? {
    inventory_uri                                = "abfss://${azurerm_storage_container.inventory["${key}/inventory"].name}@${azurerm_storage_account.store["${key}/work"].name}.dfs.core.windows.net"
    outbox_uri                                   = "abfss://${azurerm_storage_container.inventory["${key}/outbox"].name}@${azurerm_storage_account.store["${key}/work"].name}.dfs.core.windows.net"
  } : {}) }
}
