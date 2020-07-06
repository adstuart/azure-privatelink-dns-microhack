
#######################################################################
## Create Resource Group
#######################################################################

resource "azurerm_resource_group" "private-link-microhack-spoke-rg" {
  name     = "private-link-microhack-spoke-rg"
  location = var.location

 tags = {
    environment = "spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}
#######################################################################
## Create Virtual Network
#######################################################################

resource "azurerm_virtual_network" "spoke-vnet" {
  name                = "spoke-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-spoke-rg.name
  address_space       = ["10.1.0.0/16"]

  tags = {
    environment = "spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#######################################################################
## Create Subnets
#######################################################################

resource "azurerm_subnet" "spoke-infrastructure" {
  name                 = "InfrastructureSubnet"
  resource_group_name  = azurerm_resource_group.private-link-microhack-spoke-rg.name
  virtual_network_name = azurerm_virtual_network.spoke-vnet.name
  address_prefix       = "10.1.0.0/24"
}

#######################################################################
## Create VNet Peering
#######################################################################

resource "azurerm_virtual_network_peering" "spoke-hub-peer" {
  name                      = "spoke-hub-peer"
  resource_group_name       = azurerm_resource_group.private-link-microhack-spoke-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = true
  depends_on = [azurerm_virtual_network.spoke-vnet, azurerm_virtual_network.hub-vnet , azurerm_virtual_network_gateway.hub-vnet-gateway]
}

#######################################################################
## Create Network Interface
#######################################################################

resource "azurerm_network_interface" "az-mgmt-nic" {
  name                 = "az-mgmt-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.private-link-microhack-spoke-rg.name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "spoke"
    subnet_id                     = azurerm_subnet.spoke-infrastructure.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#######################################################################
## Create Virtual Machine
#######################################################################

resource "azurerm_virtual_machine" "az-mgmt-vm" {
  name                  = "az-mgmt-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.private-link-microhack-spoke-rg.name
  network_interface_ids = [azurerm_network_interface.az-mgmt-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "az-mgmt-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "az-mgmt-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    environment = "spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

