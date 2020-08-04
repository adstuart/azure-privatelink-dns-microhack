
#######################################################################
## Create Virtual Network
#######################################################################

resource "azurerm_virtual_network" "onprem-vnet" {
  name                = "onprem-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name
  address_space       = ["192.168.0.0/16"]
  dns_servers         = ["192.168.0.4"]

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Subnets
#######################################################################

resource "azurerm_subnet" "onprem-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefix       = "192.168.255.224/27"
}

resource "azurerm_subnet" "onprem-bastion-subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefix       = "192.168.1.0/27"
}

resource "azurerm_subnet" "onprem-infrastructure-subnet" {
  name                 = "InfrastructureSubnet"
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefix       = "192.168.0.0/24"
}

#######################################################################
## Create Public IPs
#######################################################################

resource "azurerm_public_ip" "onprem-bastion-pip" {
  name                = "onprem-bastion-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Bastion Service
#######################################################################

resource "azurerm_bastion_host" "onprem-bastion-host" {
  name                = "onprem-bastion-host"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name

  ip_configuration {
    name                 = "onprem-bastion-host"
    subnet_id            = azurerm_subnet.onprem-bastion-subnet.id
    public_ip_address_id = azurerm_public_ip.onprem-bastion-pip.id
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Network Interfaces
#######################################################################

resource "azurerm_network_interface" "onprem-dns-nic" {
  name                 = "onprem-dns-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  
  ip_configuration {
    name                          = "onprem-dns-nic"
    subnet_id                     = azurerm_subnet.onprem-infrastructure-subnet.id
    private_ip_address_allocation = "static"
    private_ip_address            = "192.168.0.4"
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

resource "azurerm_network_interface" "onprem-mgmt-nic" {
  name                 = "onprem-mgmt-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  
  ip_configuration {
    name                          = "onprem-mgmt-nic"
    subnet_id                     = azurerm_subnet.onprem-infrastructure-subnet.id
    private_ip_address_allocation = "static"
    private_ip_address            = "192.168.0.5"
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}


#######################################################################
## Create Virtual Machines
#######################################################################

resource "azurerm_virtual_machine" "onprem-dns-vm" {
  name                  = "onprem-dns-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.privatelink-dns-microhack-rg.name
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
    microhack   = "privatelink-dns"
  }
}

resource "azurerm_virtual_machine" "onprem-mgmt-vm" {
  name                  = "onprem-mgmt-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.privatelink-dns-microhack-rg.name
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
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Virtual Network Gateway
#######################################################################

resource "azurerm_public_ip" "onprem-vpn-gateway-pip" {
  name                = "onprem-vpn-gateway-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "onprem-vpn-gateway" {
  name                = "onprem-vpn-gateway"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name

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
    microhack   = "privatelink-dns"
  }
}