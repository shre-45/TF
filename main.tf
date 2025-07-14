terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}


provider "azurerm" {
  features {} 
  client_id       = "e60515f9-ee0a-4ad8-add1-9ddc908b0a8f"
  client_secret   = "8tH8Q~iRfO3P3BRdP9DNes53aGlvU3rKivyMRav_"
  tenant_id       = "6658e590-295a-46bd-98d2-6e02f9d3d67b"
  subscription_id = "d2545d00-6057-45e1-b852-f66f27a93531"
}



data "azurerm_resource_group" "rg1" {
  name     = "NextOpsVideos"
}

locals {
  rg_info = data.azurerm_resource_group.rg1
}

data "azurerm_virtual_network" "vnet1" {
  name                = "NextOpsVNET02"
  resource_group_name = local.rg_info.name
}

data "azurerm_subnet" "subnet1" {
  name                 = "default"
  resource_group_name  = local.rg_info.name
  virtual_network_name = data.azurerm_virtual_network.vnet1.name
}

resource "azurerm_network_security_group" "nsg1" {
  name                = "NextOps-nsg1"
  resource_group_name = "${local.rg_info.name}"
  location            = "${local.rg_info.location}"
}

# NOTE: this allows RDP from any network
resource "azurerm_network_security_rule" "ssh" {
  name                        = "ssh"
  resource_group_name         = "${local.rg_info.name}"
  network_security_group_name = "${azurerm_network_security_group.nsg1.name}"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnet_assoc" {
  subnet_id                 = data.azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

resource "azurerm_public_ip" "myVMIP" {
  name                = "myVMIP01"
  resource_group_name = "${local.rg_info.name}"
  location            = "${local.rg_info.location}"
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_network_interface" "nic1" {
  name                = "NextOpsVM-nic"
  resource_group_name = local.rg_info.name
  location            = local.rg_info.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myVMIP.id
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = "NextOpsVM"
  resource_group_name             = local.rg_info.name
  location                        = local.rg_info.location
  size                            = "Standard_B1s"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  network_interface_ids = [ azurerm_network_interface.nic1.id ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  disable_password_authentication = false
}


