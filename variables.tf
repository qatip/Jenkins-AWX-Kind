#############
# Variables #
#############

variable "subscription"{
    type = string
    description = "Subscription ID"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "rg_name" {
  type        = string
  description = "Resource Group name"
}

variable "admin_username" {
  type        = string
  description = "Admin username for both VMs"
}

variable "ssh_public_key_path" {
  type    = string
}

variable "vm1_size" {
  type        = string
  description = "VM size for Jenkins VM"
}

variable "vm2_size" {
  type        = string
  description = "VM size for AWX VM"
}

variable "vnet_address_space" {
  type        = string
  description = "CIDR for the VNet"
}

variable "subnet_prefix" {
  type        = string
  description = "CIDR for the Subnet"
}

# Lock down inbound? Provide your public IP in CIDR form; default is open (*)
variable "allow_inbound_cidr" {
  type        = string
  description = "CIDR allowed to reach SSH/HTTP/ports. e.g. 203.0.113.10/32"
}