# Terraform Infrastructure for Infinion Weather API

## Overview

This directory contains the Infrastructure-as-Code for deploying the Infinion Weather API to Azure. Instead of manually clicking around in the Azure portal, I wrote code to define and deploy everything. It's repeatable, version-controlled, and actually makes sense.

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

## Why Modules?

When I started, I thought about putting everything in one `main.tf` file. That would've been a mess. Splitting into modules means:

- **Network module** - All networking concerns in one place
- **ACR module** - Container registry setup
- **AKS module** - Kubernetes cluster and node pools
- **RBAC module** - Just permissions and role assignments

If something breaks with networking, I know exactly where to look. If I need to reuse the ACR setup in another project, I can just copy the module.

## Infrastructure Components

### Network (`modules/network/`)

Creates:

- **Virtual Network** (VNet) - 10.0.0.0/16

  - This is the isolated network where everything lives

- **Subnet** - 10.0.1.0/24

  - Where the AKS cluster gets deployed
  - Has service endpoints enabled for Storage and Container Registry

- **Network Security Group** (NSG)
  - AllowHTTP (port 80)
  - AllowHTTPS (port 443)
  - Nothing else gets through

### Container Registry (`modules/acr/`)

Creates:

- **Azure Container Registry** (ACR)

  - Name generated: `devacrweather20251104` (environment + service + timestamp)
  - SKU: Standard (good balance of features and cost)
  - Admin access disabled (we use managed identities instead)

- **Managed Identity for ACR Pull**
  - This is what I use instead of storing passwords
  - The AKS cluster has permission to pull from ACR without hardcoding credentials

### Kubernetes Cluster (`modules/aks/`)

Creates:

- **AKS Cluster** named `dev-aks`

  - Kubernetes version: 1.32
  - Uses managed identity for authentication

- **System Node Pool**

  - 2 nodes running Linux
  - Runs Kubernetes system components
  - Spread across 3 availability zones (if available)

- **User Node Pool**
  - 2 to 3 nodes (auto-scaling)
  - Where my application pods run
  - Also spread across availability zones

### RBAC (`modules/rbac/`)

Simple but important:

- Grants AKS cluster permission to pull images from ACR
- Without this, pods would get `ImagePullBackOff` errors

## How to Deploy

### Prerequisites

1. Azure CLI installed and authenticated

   ```bash
   az login
   ```

2. Terraform installed

   ```bash
   terraform --version  # Should be 1.0+
   ```

3. Set your subscription
   ```bash
   az account set --subscription YOUR_SUBSCRIPTION_ID
   ```

### Deploy Steps

```bash
# Navigate to the dev environment
cd terraform/environments/dev

# Initialize Terraform (downloads providers, sets up backend)
terraform init

# See what Terraform will create
terraform plan -out=tfplan

# Review the output carefully - lots of resources will be created!

# Actually deploy it
terraform apply tfplan

# Save the outputs
terraform output -json > outputs.json
```

### What Gets Created

- 1 Resource Group (already exists)
- 1 Virtual Network
- 1 Subnet
- 1 Network Security Group
- 1 Container Registry
- 1 AKS Cluster with 2 node pools (4 VMs total)
- 2 Managed Identities
- 1 Role Assignment

**Total: 14 Azure resources**

### Costs

This isn't free. Roughly:

- AKS cluster: ~$70/month
- VMs (4x Standard_D2s_v3): ~$120/month
- Container Registry: ~$10/month
- Network/Storage: ~$10/month

**Total: ~$210/month in Azure costs**

Make sure to `terraform destroy` when you're done testing!

## Variables Explained

### `terraform.tfvars`

```hcl
resource_group_name = "herdeybayor4realgmail.com"
acr_name_suffix     = "20251104"
```

The resource group already exists (you create it manually in Azure). The ACR name suffix makes the registry name unique (Azure requires globally unique ACR names).

### `variables.tf`

- `environment` - "dev" (used for naming resources)
- `kubernetes_version` - Which Kubernetes version to use
- `system_node_count` - How many system nodes (usually 2-3)
- `user_node_count` - How many app nodes (1-3, with auto-scaling)
- `vnet_cidr` - The network IP range (10.0.0.0/16)

I kept defaults reasonable so you don't have to change much.

## Outputs

After `terraform apply`, get values with:

```bash
terraform output -json
```

Or specific outputs:

```bash
# Get the container registry URL
terraform output -raw acr_login_server

# Get the AKS cluster name
terraform output -raw aks_name

# Get the kubeconfig
terraform output -raw kube_config
```

These values are used by GitHub Actions to:

- Push images to ACR
- Connect to the AKS cluster
- Deploy applications

## Troubleshooting

### "Insufficient cores"

Azure subscription limits. You can't create 4 VMs. Either:

1. Request quota increase in Azure Portal
2. Use smaller VM sizes in variables.tf

### "Resource group not found"

The resource group doesn't exist. Create it:

```bash
az group create -n herdeybayor4realgmail.com -l uksouth
```

### "Insufficient quota for SKU Standard_D2s_v3"

Same as cores issue. Try `Standard_B2s` instead (cheaper, slower).

### State lock error

Terraform state is locked (maybe deploy crashed). Unlock it:

```bash
terraform force-unlock LOCK_ID
```

## Cleanup

When you're done with the assessment:

```bash
cd terraform/environments/dev

# See what will be deleted
terraform plan -destroy

# Actually delete everything
terraform destroy
```

This removes all 14 resources and stops the Azure billing immediately.

## Lessons from Building This

1. **Managed Identities > Secrets**

   - I use managed identities for AKS to access ACR
   - No passwords to rotate, no secrets to leak
   - Azure handles it automatically

2. **Multiple Node Pools**

   - System pool for Kubernetes internals
   - User pool for my applications
   - They can scale independently

3. **Availability Zones**

   - Spread nodes across 3 zones
   - If one zone fails, still have 2
   - Better reliability with minimal extra cost

4. **Network Isolation**

   - NSG restricts traffic in/out
   - Only HTTP/HTTPS allowed inbound
   - Everything else blocked

5. **Modular Design**
   - Each module has one job
   - Easy to update, easy to reuse
   - Clear dependencies

## If I Were to Improve This

1. **Staging Environment** - Add `environments/staging/` with slightly different config
2. **Auto-scaling** - Set up cluster autoscaler to add nodes when needed
3. **Monitoring** - Enable Azure Monitor integration
4. **Storage** - Add managed disks or blob storage for state
5. **CI/CD Integration** - Trigger Terraform runs from GitHub Actions

But for an assessment, this is solid. It demonstrates I understand infrastructure, can write code that's not application code, and can manage Azure resources programmatically.
