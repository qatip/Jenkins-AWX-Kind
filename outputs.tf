output "vm1_public_ip" {
  value       = azurerm_public_ip.vm1_pip.ip_address
  description = "Public IP for VM1 (Jenkins)"
}

output "vm2_public_ip" {
  value       = azurerm_public_ip.vm2_pip.ip_address
  description = "Public IP for VM2 (AWX)"
}

output "ssh_examples" {
  description = "Ready-to-use SSH commands"
  value = [
    "ssh ${var.admin_username}@${azurerm_public_ip.vm1_pip.ip_address}",
    "ssh ${var.admin_username}@${azurerm_public_ip.vm2_pip.ip_address}"
  ]
}

output "ssh_get_jenkins_password_bash" {
  value = "ssh -i ~/.ssh/azure_automation_rsa ${var.admin_username}@${azurerm_public_ip.vm1_pip.ip_address} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
}

output "ssh_get_jenkins_password_powershell" {
  value = <<EOT
ssh -i "$env:USERPROFILE\\.ssh\\azure_automation_rsa" ${var.admin_username}@${azurerm_public_ip.vm1_pip.ip_address} "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
EOT
}

