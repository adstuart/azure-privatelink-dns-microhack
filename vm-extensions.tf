
##########################################################
## Install DNS role on onprem and AZ DNS servers
##########################################################

resource "azurerm_virtual_machine_extension" "install-dns-onprem-dc" {
    
  name                 = "install-dns-onprem-dc"
  virtual_machine_id   = azurerm_virtual_machine.onprem-dns-vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

   settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted Install-WindowsFeature -Name DNS -IncludeAllSubFeature -IncludeManagementTools; Add-DnsServerForwarder -IPAddress 8.8.8.8 -PassThru; exit 0"
    }
SETTINGS
}

resource "azurerm_virtual_machine_extension" "install-dns-az-dc" {
    
  name                 = "install-dns-az-dc"
  virtual_machine_id   = azurerm_virtual_machine.az-dns-vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

   settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted Install-WindowsFeature -Name DNS -IncludeAllSubFeature -IncludeManagementTools; exit 0"
    }
SETTINGS
}

##########################################################
## Execute post-config scripts
##########################################################

resource "azurerm_virtual_machine_extension" "post-config" {
  name                 = "post-config"
  virtual_machine_id   = azurerm_virtual_machine.onprem-mgmt-vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

 protected_settings = <<PROTECTED_SETTINGS
    {
      "commandtoExecute": "powershell.exe -ExecutionPolicy Unrestricted -File privatelink-post-deploy.ps1"
    }
  PROTECTED_SETTINGS

  settings = <<SETTINGS
    {
        "fileUris": [
          "https://gist.githubusercontent.com/carlsyner/ac6af5fd87abbad5e13e08e88f3cad9a/raw/d31a57774c1640831da62b8d394a104ca1b3e7ad/privatelink-post-deploy.ps1"
          ]
    }
  SETTINGS
}