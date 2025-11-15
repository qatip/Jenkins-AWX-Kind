variable "sub_id" {
  description = "Your Subscription ID here"
}

variable "location" {
  description = "Azure region for the backend RG and storage"
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the Resource Group for Terraform backend storage"
  default     = "tfstate-rg"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (lowercase, 3-24 chars). Leave blank to auto-generate."
  default     = ""
}

variable "container_name" {
  description = "Blob container name for Terraform state files"
  default     = "tfstate"
}