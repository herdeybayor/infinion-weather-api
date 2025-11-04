output "aks_id" {
  value       = azurerm_kubernetes_cluster.main.id
  description = "AKS cluster ID"
}

output "aks_name" {
  value       = azurerm_kubernetes_cluster.main.name
  description = "AKS cluster name"
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
  description = "Kubernetes config"
}

output "kube_config_context" {
  value       = azurerm_kubernetes_cluster.main.name
  description = "Kubernetes context name"
}

output "aks_identity_principal_id" {
  value       = azurerm_user_assigned_identity.aks.principal_id
  description = "AKS cluster identity principal ID"
}