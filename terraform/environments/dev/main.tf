terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Get current resource group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Network Module
module "network" {
  source = "../../modules/network"

  environment         = var.environment
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
}

# ACR Module
module "acr" {
  source = "../../modules/acr"

  environment         = var.environment
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = var.acr_sku
  acr_name_suffix     = var.acr_name_suffix
}

# AKS Module
module "aks" {
  source = "../../modules/aks"

  environment              = var.environment
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  kubernetes_version       = var.kubernetes_version
  subnet_id                = module.network.subnet_id
  system_node_count        = var.system_node_count
  system_vm_size           = var.system_vm_size
  user_node_count          = var.user_node_count
  user_node_min_count      = var.user_node_min_count
  user_node_max_count      = var.user_node_max_count
  user_vm_size             = var.user_vm_size
  availability_zones       = var.availability_zones
  service_cidr             = var.service_cidr
  dns_service_ip           = var.dns_service_ip
}

# RBAC Module
module "rbac" {
  source = "../../modules/rbac"

  acr_id                      = module.acr.acr_id
  aks_identity_principal_id   = module.aks.aks_identity_principal_id
}