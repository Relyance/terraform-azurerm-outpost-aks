resource "azurerm_kubernetes_cluster" "installation" {
  for_each                          = var.installations
  name                              = local.names[each.key].base
  resource_group_name               = azurerm_resource_group.installation[each.key].name
  location                          = each.value.location
  dns_prefix                        = local.names[each.key].base
  kubernetes_version                = each.value.kubernetes_version
  sku_tier                          = each.value.pricing_tier
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  local_account_disabled            = true
  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    tenant_id          = var.tenant_id
    azure_rbac_enabled = true
  }
  api_server_access_profile {
    authorized_ip_ranges = var.management_api_cidrs
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster[each.key].id]
  }
  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet[each.key].client_id
    object_id                 = azurerm_user_assigned_identity.kubelet[each.key].principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet[each.key].id
  }
  node_provisioning_profile {
    mode               = each.value.scaling_mode == "nap" ? "Auto" : "Manual"
    default_node_pools = "None"
  }
  default_node_pool {
    name                         = "system"
    vm_size                      = each.value.system_vm_size
    node_count                   = each.value.system_node_count
    auto_scaling_enabled         = false
    type                         = "VirtualMachineScaleSets"
    only_critical_addons_enabled = true
    os_sku                       = "Ubuntu"
    vnet_subnet_id               = azurerm_subnet.nodes[each.key].id
    node_labels                  = { "inhost-node-role" = "system", "inhost-deployment" = each.value.deployment_id }
    # AKS persists these defaults on creation; pin them to avoid perpetual drift.
    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
    }
  }
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "172.20.0.0/16"
    dns_service_ip      = "172.20.0.10"
  }
  workload_autoscaler_profile { keda_enabled = true }
  storage_profile {
    disk_driver_enabled         = true
    file_driver_enabled         = false
    blob_driver_enabled         = false
    snapshot_controller_enabled = true
  }
  tags       = local.names[each.key].tags
  depends_on = [azurerm_role_assignment.cluster_network, azurerm_role_assignment.kubelet_operator]
}
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  for_each              = { for key, v in var.installations : key => v if v.scaling_mode == "cluster_autoscaler" }
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.installation[each.key].id
  vm_size               = each.value.workload_vm_size
  mode                  = "User"
  os_sku                = "Ubuntu"
  vnet_subnet_id        = azurerm_subnet.nodes[each.key].id
  auto_scaling_enabled  = true
  min_count             = 0
  max_count             = each.value.workload_max_nodes
  node_count            = 0
  node_labels           = { "inhost-node-role" = "workload", "inhost-deployment" = each.value.deployment_id }
  node_taints           = ["inhost-workload=true:NoSchedule"]
  tags                  = local.names[each.key].tags
  upgrade_settings {
    max_surge                     = "10%"
    drain_timeout_in_minutes      = 0
    node_soak_duration_in_minutes = 0
  }
  lifecycle { ignore_changes = [node_count] }
}
