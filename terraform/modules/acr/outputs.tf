output "acr_id" {
  value       = azurerm_container_registry.main.id
  description = "Container Registry ID"
}

output "acr_login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "ACR login server URL"
}

output "acr_pull_identity_id" {
  value       = azurerm_user_assigned_identity.acr_pull.id
  description = "User assigned identity for ACR pull"
}

output "acr_pull_identity_principal_id" {
  value       = azurerm_user_assigned_identity.acr_pull.principal_id
  description = "Principal ID of ACR pull identity"
}