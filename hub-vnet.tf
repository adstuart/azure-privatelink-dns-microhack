#######################################################################
## Define Locals
#######################################################################

locals {
   shared-key           = "4-v3ry-53cr37-1p53c-5h4r3d-k3y"
}

#######################################################################
## Create Resource Groups
#######################################################################

resource "azurerm_resource_group" "private-link-microhack-hub-rg" {
  name     = "private-link-microhack-hub-rg"
  location = var.location

  tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}


#######################################################################
## Create Virtual Networks
#######################################################################

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "hub-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-hub-rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#######################################################################
## Create Subnets
#######################################################################

resource "azurerm_subnet" "hub-gateway-subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.private-link-microhack-hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefix       = "10.0.255.224/27"
}

resource "azurerm_subnet" "hub-dns" {
  name                 = "DNSSubnet"
  resource_group_name  = azurerm_resource_group.private-link-microhack-hub-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefix       = "10.0.0.0/24"
}

#######################################################################
## Create Network Peering
#######################################################################

resource "azurerm_virtual_network_peering" "hub-spoke-peer" {
  name                      = "hub-spoke-peer"
  resource_group_name       = azurerm_resource_group.private-link-microhack-hub-rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
  use_remote_gateways       = false
  depends_on = [azurerm_virtual_network.spoke-vnet, azurerm_virtual_network.hub-vnet, azurerm_virtual_network_gateway.hub-vnet-gateway]
}

#######################################################################
## Create Network Interface
#######################################################################

resource "azurerm_network_interface" "az-dns-nic" {
  name                 = "az-dns-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.private-link-microhack-hub-rg.name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "az-dns-nic"
    subnet_id                     = azurerm_subnet.hub-dns.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#######################################################################
## Create Virtual Machine
#######################################################################

resource "azurerm_virtual_machine" "az-dns-vm" {
  name                  = "az-dns-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.private-link-microhack-hub-rg.name
  network_interface_ids = [azurerm_network_interface.az-dns-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "az-dns-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "az-dns-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

   tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#############################################################################
## Create Virtual Network Gateway
#############################################################################

resource "azurerm_public_ip" "hub-vpn-gateway-pip" {
  name                = "hub-vpn-gateway-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-hub-rg.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "hub-vnet-gateway" {
  name                = "hub-vpn-gateway"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-hub-rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.hub-vpn-gateway-pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub-gateway-subnet.id
  }
  depends_on = [azurerm_public_ip.hub-vpn-gateway-pip]

   tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}

#######################################################################
## Create Connections
#######################################################################

resource "azurerm_virtual_network_gateway_connection" "hub-onprem-conn" {
  name                = "hub-onprem-conn"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-hub-rg.name

  type           = "Vnet2Vnet"
  routing_weight = 1

  virtual_network_gateway_id      = azurerm_virtual_network_gateway.hub-vnet-gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem-vpn-gateway.id

  shared_key = local.shared-key
}

resource "azurerm_virtual_network_gateway_connection" "onprem-hub-conn" {
  name                = "onprem-hub-conn"
  location            = var.location
  resource_group_name = azurerm_resource_group.private-link-microhack-hub-rg.name
  type                            = "Vnet2Vnet"
  routing_weight = 1
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.onprem-vpn-gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.hub-vnet-gateway.id

  shared_key = local.shared-key

   tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack    = "private-link"
  }
}