output "backend_config_jenkins_awx" {
  value = {
    resource_group_name  = azurerm_resource_group.rg.name
    storage_account_name = azurerm_storage_account.sa.name
    container_name       = azurerm_storage_container.container.name
    key                  = local.jenkins_awx_key
  }
}

output "backend_config_resources" {
  value = {
    resource_group_name  = azurerm_resource_group.rg.name
    storage_account_name = azurerm_storage_account.sa.name
    container_name       = azurerm_storage_container.container.name
    key                  = local.resources_key
  }
}
