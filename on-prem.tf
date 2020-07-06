
#######################################################################
## Create Resource Group
#######################################################################

resource "azurerm_resource_group" "private-link-microhack-onprem-rg" {
  name     = "private-link-microhack-onprem-rg"
  location = var.location

 tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#######################################################################
## Create Virtual Network
#######################################################################

resource "azurerm_virtual_network" "onprem-vnet" {
  name                = "onprem-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-onprem-rg.name
  address_space       = ["192.168.0.0/16"]
  dns_servers         = ["192.168.0.4"]

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#######################################################################
## Create Subnets
#######################################################################

resource "azurerm_subnet" "onprem-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.private-link-microhack-onprem-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefix       = "192.168.255.224/27"
}

resource "azurerm_subnet" "onprem-infrastructure-subnet" {
  name                 = "InfrastructureSubnet"
  resource_group_name  = azurerm_resource_group.private-link-microhack-onprem-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefix       = "192.168.0.0/24"
}

#######################################################################
## Create Public IPs
#######################################################################

resource "azurerm_public_ip" "onprem-mgmt-pip" {
    name                 = "onprem-mgmt-pip"
    location            = var.location
    resource_group_name = azurerm_resource_group.private-link-microhack-onprem-rg.name
    allocation_method   = "Static"

    tags = {
        environment = "onprem"
        deployment  = "terraform"
        microhack    = "private-link"
    }
}

#######################################################################
## Create Network Interfaces
#######################################################################

resource "azurerm_network_interface" "onprem-dns-nic" {
  name                 = "onprem-dns-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.private-link-microhack-onprem-rg.name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "onprem-dns-nic"
    subnet_id                     = azurerm_subnet.onprem-infrastructure-subnet.id
    private_ip_address_allocation = "static"
    private_ip_address            = "192.168.0.4"
  }
      
    tags = {
        environment = "onprem"
        deployment  = "terraform"
        microhack    = "private-link"
    }
}

resource "azurerm_network_interface" "onprem-mgmt-nic" {
  name                 = "onprem-mgmt-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.private-link-microhack-onprem-rg.name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "onprem-mgmt-nic"
    subnet_id                     = azurerm_subnet.onprem-infrastructure-subnet.id
    private_ip_address_allocation = "static"
    private_ip_address            = "192.168.0.5"
    public_ip_address_id          = azurerm_public_ip.onprem-mgmt-pip.id
  }

    tags = {
        environment = "onprem"
        deployment  = "terraform"
        microhack    = "private-link"
    }
}


##########################################################
## Create Network Security Group and rule
###########################################################

resource "azurerm_network_security_group" "onprem-mgmt-nsg" {
    name                = "onprem-mgmt-nsg"
    location            = var.location
    resource_group_name = azurerm_resource_group.private-link-microhack-onprem-rg.name

    security_rule {
        name                       = "Allow_RDP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
      source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "onprem"
        deployment  = "terraform"
        microhack    = "private-link"
    }
}

resource "azurerm_subnet_network_security_group_association" "mgmt-nsg-association" {
  subnet_id                 = azurerm_subnet.onprem-infrastructure-subnet.id
  network_security_group_id = azurerm_network_security_group.onprem-mgmt-nsg.id
}

#######################################################################
## Create Virtual Machines
#######################################################################

resource "azurerm_virtual_machine" "onprem-dns-vm" {
  name                  = "onprem-dns-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.private-link-microhack-onprem-rg.name
  network_interface_ids = [azurerm_network_interface.onprem-dns-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "onprem-dns-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "onprem-dns-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

resource "azurerm_virtual_machine" "onprem-mgmt-vm" {
  name                  = "onprem-mgmt-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.private-link-microhack-onprem-rg.name
  network_interface_ids = [azurerm_network_interface.onprem-mgmt-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "onprem-mgmt-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "onprem-mgmt-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#######################################################################
## Create Virtual Network Gateway
#######################################################################

resource "azurerm_public_ip" "onprem-vpn-gateway-pip" {
  name                = "onprem-vpn-gateway-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-onprem-rg.name
  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "onprem-vpn-gateway" {
  name                = "onprem-vpn-gateway"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-onprem-rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.onprem-vpn-gateway-pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.onprem-gateway-subnet.id
  }
  depends_on = [azurerm_public_ip.onprem-vpn-gateway-pip]

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}
