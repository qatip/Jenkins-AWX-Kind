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
  subscription_id = var.subscription
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  final_storage_account_name = (
    var.storage_account_name != ""
    ? var.storage_account_name
    : "tfstate${random_id.suffix.hex}"
  )

  jenkins_awx_key   = "jenkins-awx.tfstate"
  resources_key     = "resources.tfstate"
}

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
