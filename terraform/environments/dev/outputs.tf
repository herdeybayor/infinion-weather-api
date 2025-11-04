# Network Outputs
output "vnet_id" {
  value       = module.network.vnet_id
  description = "Virtual Network ID"
}

output "subnet_id" {
  value       = module.network.subnet_id
  description = "AKS Subnet ID"
}

output "nsg_id" {
  value       = module.network.nsg_id
  description = "Network Security Group ID"
}

# ACR Outputs
output "acr_id" {
  value       = module.acr.acr_id
  description = "Container Registry ID"
}

output "acr_login_server" {
  value       = module.acr.acr_login_server
  description = "ACR login server URL (use this to push images)"
}

output "acr_pull_identity_id" {
  value       = module.acr.acr_pull_identity_id
  description = "User assigned identity for ACR pull"
}

# AKS Outputs
output "aks_id" {
  value       = module.aks.aks_id
  description = "AKS cluster ID"
}

output "aks_name" {
  value       = module.aks.aks_name
  description = "AKS cluster name (use for kubectl commands)"
}

output "kube_config_context" {
  value       = module.aks.kube_config_context
  description = "Kubernetes context name"
}

output "aks_identity_principal_id" {
  value       = module.aks.aks_identity_principal_id
  description = "AKS cluster identity principal ID"
}

# RBAC Outputs
output "role_assignment_id" {
  value       = module.rbac.role_assignment_id
  description = "RBAC role assignment ID"
}

# Summary Outputs
output "deployment_summary" {
  value = {
    resource_group        = data.azurerm_resource_group.main.name
    region                = data.azurerm_resource_group.main.location
    acr_server            = module.acr.acr_login_server
    aks_cluster_name      = module.aks.aks_name
    environment           = var.environment
  }
  description = "Quick reference for deployed infrastructure"
}
