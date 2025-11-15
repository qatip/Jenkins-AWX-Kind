variable "subscription"{}
variable "location" {}
variable "rg_name" {}
variable "admin_username" {}
variable "ssh_public_key_path" { type = string }
variable "vm1_size" {}
variable "vm2_size" {}
variable "vnet_address_space" { type = string }
variable "subnet_prefix" { type = string }
variable "allow_inbound_cidr" { type = string }