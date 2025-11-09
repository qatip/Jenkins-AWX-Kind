output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "vm_public_ip" {
  description = "Public IP address of the VM (null unless assigned)"
  value       = azurerm_linux_virtual_machine.vm.public_ip_address
}
