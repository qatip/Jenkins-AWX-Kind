terraform {
  backend "azurerm" {
    resource_group_name  = "backend_sa_rg"
    storage_account_name = "enter storage account name here"
    container_name       = "tfstate"
    key                  = "jenkins-awx.tfstate"
  }
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.107.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription
  features {}
}

locals {
  awx_install_script = replace(file("${path.module}/install_awx_kind.sh"), "\r", "")
  jenkins_script_raw = replace(file("${path.module}/install_jenkins_azure.sh"), "\r", "")
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
  tags = {
    Project = "Jenkins_AWX"
    Owner   = "Michael_CG"
  }
}

# Network + Shared NSG
resource "azurerm_virtual_network" "vnet" {
  name                = "lab-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "default-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_prefix]
}


resource "azurerm_network_security_group" "nsg" {
  name                = "lab-nsg-shared"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # SSH from your workstation
  security_rule {
    name                       = "Allow-SSH-22"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22"]
    source_address_prefix      = var.allow_inbound_cidr
    destination_address_prefix = "*"
  }

  # Jenkins UI from your workstation
  security_rule {
    name                       = "Allow-Jenkins-8080"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080"]
    source_address_prefix      = var.allow_inbound_cidr
    destination_address_prefix = "*"
  }

  # AWX from your workstation (public)
  security_rule {
    name                       = "Allow-AWX-30080"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["30080"]
    source_address_prefix      = var.allow_inbound_cidr
    destination_address_prefix = "*"
  }

  # HTTP from your workstation
  security_rule {
    name                       = "Allow-HTTP-80"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80"]
    source_address_prefix      = var.allow_inbound_cidr
    destination_address_prefix = "*"
  }

  # Allow VNet-internal traffic to the same ports
  security_rule {
    name                       = "Allow-VNet-to-AWX"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "30080"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Default outbound allow
  security_rule {
    name                       = "Allow-Internet-Outbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Public IPs
resource "azurerm_public_ip" "vm1_pip" {
  name                = "vm1-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "vm2_pip" {
  name                = "vm2-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NICs
resource "azurerm_network_interface" "vm1_nic" {
  name                = "vm1-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1_pip.id
  }
}

resource "azurerm_network_interface" "vm2_nic" {
  name                = "vm2-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2_pip.id
  }
}

# VM1 (Jenkins host)
resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "VM1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm1_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.vm1_nic.id
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "vm1-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

custom_data = base64encode(
  templatefile("${path.module}/cloud-init-jenkins.tftpl", {
    script_b64 = base64encode(local.jenkins_script_raw)
  })
)
  tags = {
    Role = "Jenkins"
  }
}

# VM2 (AWX host)
resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "VM2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm2_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.vm2_nic.id
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "vm2-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-awx.tftpl", {
    script_b64 = base64encode(local.awx_install_script)
  }))

  tags = {
    Role = "AWX"
  }
}

