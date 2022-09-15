terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"     
	  version = "2.92.0"
    }
  }
}

provider "azurerm" {
   features {}
}

#######################################################################
## Create Resource Group
#######################################################################

resource "azurerm_resource_group" "privatelink-dns-microhack-rg" {
  name     = "privatelink-dns-microhack-rg"
  location = var.location

  tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}
