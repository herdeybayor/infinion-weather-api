# Terraform Infrastructure for Infinion Weather API

## Overview

Infrastructure-as-Code deployment for the Infinion Weather API on Azure. All 14 resources—networking, container registry, Kubernetes cluster, and RBAC—are defined in Terraform. This ensures reproducibility, version control, and eliminates manual portal configuration.

## Directory Structure

```
terraform/
├── README.md                 # This file
├── modules/                  # Reusable infrastructure components
│   ├── network/              # VNet, Subnet, Network Security Group
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── acr/                  # Container Registry for Docker images
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── aks/                  # Kubernetes cluster and node pools
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── rbac/                 # Role-based access control and permissions
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    └── dev/                  # Development environment configuration
        ├── main.tf           # Module orchestration
        ├── variables.tf      # Environment variables
        ├── terraform.tfvars  # Actual values
        ├── backend.tf        # Remote state storage
        └── outputs.tf        # Values exported for other tools
```

## Architecture

### Modular Design

Separated into four modules to maintain clear separation of concerns:

- **Network** - VNet (10.0.0.0/16), subnet, NSG with HTTP/HTTPS rules
- **ACR** - Azure Container Registry for storing application images
- **AKS** - Kubernetes cluster with separate system and application node pools
- **RBAC** - Service principals and role bindings for authentication

Each module is self-contained and can be reused in other projects. Dependencies between modules are explicit through outputs.

### Network Configuration

- **VNet**: 10.0.0.0/16 with single subnet 10.0.1.0/24
- **NSG**: Restricts inbound to HTTP (80) and HTTPS (443) only
- **Service Endpoints**: Enabled for ACR and Storage to allow private connectivity

### Container Registry

- **SKU**: Standard (balanced for cost and features)
- **Admin Access**: Disabled in favor of managed identities
- **Managed Identity**: AKS can pull images without stored credentials

### Kubernetes Cluster

- **Version**: 1.32 (latest stable at deployment time)
- **System Node Pool**: 2 Linux nodes across availability zones, runs Kubernetes internals
- **Application Node Pool**: 2-3 nodes with autoscaling, runs workloads
- **Authentication**: Managed identity for secure Azure API access

### Identity & Access

- AKS cluster uses managed identity for Azure API calls
- Service principal for GitHub Actions CI/CD
- RBAC binding: AKS identity has `AcrPull` role on ACR

## Deployment

### Prerequisites

```bash
# Verify installations
terraform version          # 1.0+
az version               # Latest Azure CLI
az login                 # Authenticate with Azure
az account set --subscription YOUR_SUBSCRIPTION_ID
```

### Deploy Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform (downloads providers, configures backend)
terraform init

# Review planned changes
terraform plan -out=tfplan

# Deploy
terraform apply tfplan

# Export outputs for CI/CD integration
terraform output -json > outputs.json
```

### What Gets Created

- 1 Resource Group (pre-existing)
- 1 Virtual Network + Subnet
- 1 Network Security Group
- 1 Container Registry
- 1 AKS Cluster with 2 node pools
- 2 Managed Identities
- 1 Role Assignment

**Total: 14 Azure resources**

### Cost Estimate

- AKS cluster: ~$70/month
- 4x Standard_D2s_v3 VMs: ~$120/month
- Container Registry: ~$10/month
- Network/Storage: ~$10/month

**Total: ~$210/month**

Use `terraform destroy` to clean up when finished.

## Configuration

### Variables (`variables.tf`)

- `environment` - Environment name (used for resource naming)
- `kubernetes_version` - Kubernetes version to deploy
- `system_node_count` - System pool size (typically 2-3)
- `user_node_count` - Application pool size (1-3, can autoscale)
- `vnet_cidr` - Virtual network CIDR block

### Values (`terraform.tfvars`)

```hcl
resource_group_name = "your-resource-group"
acr_name_suffix     = "20251105"  # Timestamp ensures globally unique ACR name
```

## Outputs

After deployment, access values with:

```bash
# All outputs as JSON
terraform output -json

# Specific values
terraform output -raw acr_login_server  # For pushing images
terraform output -raw aks_name          # For kubectl configuration
terraform output -raw kube_config       # Kubernetes credentials
```

These outputs are consumed by the GitHub Actions CI/CD pipeline for deployment automation.

## Troubleshooting

### "Insufficient cores"

Azure subscription has VM quota limits. Either request a quota increase in the Azure Portal or reduce `user_node_count` or use smaller VM sizes.

### "Resource group not found"

Create the resource group first:

```bash
az group create -n your-resource-group -l uksouth
```

### "State lock" errors

Terraform state is locked (previous deployment crashed). Unlock with:

```bash
terraform force-unlock LOCK_ID
```

## Cleanup

```bash
cd terraform/environments/dev
terraform plan -destroy  # Review what will be deleted
terraform destroy        # Delete all resources
```

All 14 resources and associated costs are removed immediately.

## Design Decisions

**Managed Identities over Service Principal Secrets**: AKS uses managed identity to access ACR. No credentials to rotate or leak. Azure handles lifecycle automatically.

**Multiple Node Pools**: System pool isolates Kubernetes infrastructure from application workloads. Allows independent scaling and maintenance.

**Availability Zones**: Nodes spread across multiple AZs. Single zone failure doesn't impact service.

**Deny-by-Default Networking**: NSG allows only HTTP/HTTPS inbound. All other traffic blocked at the network level.

**Remote State Management**: Terraform state stored in Azure Storage Account with encryption. Prevents accidental commits of sensitive data and enables team collaboration.

## Next Steps

- GitHub Actions workflow consumes Terraform outputs to authenticate with ACR and AKS
- All subsequent deployments use these resources; no manual portal access needed
- State is immutable; infrastructure changes tracked through Terraform and Git
