output "vnet_id" {
  value       = azurerm_virtual_network.main.id
  description = "Virtual Network ID"
}

output "subnet_id" {
  value       = azurerm_subnet.aks.id
  description = "AKS Subnet ID"
}

output "nsg_id" {
  value       = azurerm_network_security_group.aks.id
  description = "Network Security Group ID"
}