terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.sub_id
}

# ---------- RANDOM SUFFIX ----------
resource "random_id" "suffix" {
  byte_length = 4
}

# ---------- LOCALS ----------
locals {
  # if user provided a name, use it; otherwise build one
  final_storage_account_name = (
    var.storage_account_name != ""
    ? var.storage_account_name
    : "tfstate${random_id.suffix.hex}"
  )

  # we want two keys in the SAME container
  jenkins_awx_key   = "jenkins-awx.tfstate"
  resources_key     = "resources.tfstate"
}

# ---------- RESOURCES ----------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "sa" {
  name                     = local.final_storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
  name                  = var.container_name
  storage_account_id = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# ---------- OUTPUTS ----------
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
