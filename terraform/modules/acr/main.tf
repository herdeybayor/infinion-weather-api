# Create Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = replace("${var.environment}acr${var.acr_name_suffix}", "-", "")
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  admin_enabled = false  # Security: Use managed identity instead

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create User Assigned Identity for AKS to pull images
resource "azurerm_user_assigned_identity" "acr_pull" {
  name                = "${var.environment}-acr-pull-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Grant AKS identity permission to pull from ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope              = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id       = azurerm_user_assigned_identity.acr_pull.principal_id
}