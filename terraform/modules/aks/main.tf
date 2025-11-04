# Create User Assigned Identity for AKS cluster
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.environment}-aks-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Create AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.environment}-aks"
  kubernetes_version  = var.kubernetes_version

  # System node pool configuration
  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_vm_size
    type                = "VirtualMachineScaleSets"
    zones               = var.availability_zones
    vnet_subnet_id      = var.subnet_id
    os_disk_size_gb     = 50
    max_pods            = 110

    tags = {
      NodePool = "System"
    }
  }

  # Identity configuration
  identity {
    type            = "UserAssigned"
    identity_ids    = [azurerm_user_assigned_identity.aks.id]
  }

  # Network configuration
  network_profile {
    network_plugin      = "azure"
    network_policy      = "azure"  # Security: Enable network policies
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
  }

  # RBAC configuration
  role_based_access_control_enabled = true

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [azurerm_user_assigned_identity.aks]
}

# Create User Node Pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_vm_size
  node_count            = var.user_node_count
  zones                 = var.availability_zones
  vnet_subnet_id        = var.subnet_id
  max_pods              = 110
  os_disk_size_gb       = 50
  enable_auto_scaling   = true
  min_count             = var.user_node_min_count
  max_count             = var.user_node_max_count

  tags = {
    NodePool = "User"
  }
}