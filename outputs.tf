
output "public_ip_address" {
  description = "The actual ip address allocated to the On Prem Management VM"
  value       = azurerm_public_ip.onprem-mgmt-pip.ip_address
}