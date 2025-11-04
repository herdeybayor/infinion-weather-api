# Grant ACR pull permission to AKS identity
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope              = var.acr_id
  role_definition_name = "AcrPull"
  principal_id       = var.aks_identity_principal_id
}