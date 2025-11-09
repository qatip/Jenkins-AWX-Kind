variable "resource_group_name" {}
variable "vnet_name" {}
variable "subnet_name" {}
variable "vm_name" { default = "webdemo01" }
variable "admin_user" { default = "azureuser" }
variable "ssh_public_key_path" { default = "~/.ssh/azure_automation_rsa.pub" }
variable "ssh_public_key" {
  description = "SSH public key text"
}
variable "sub-id" {}
