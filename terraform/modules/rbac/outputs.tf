output "role_assignment_id" {
  value       = azurerm_role_assignment.aks_acr_pull.id
  description = "Role assignment ID"
}