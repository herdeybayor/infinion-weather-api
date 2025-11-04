variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "vnet_cidr" {
  description = "VNet CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "AKS subnet CIDR"
  type        = string
  default     = "10.0.0.0/22"
}

variable "acr_sku" {
  description = "ACR SKU"
  type        = string
  default     = "Standard"
}

variable "acr_name_suffix" {
  description = "ACR name suffix for uniqueness"
  type        = string
  default     = "weather"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "system_node_count" {
  description = "System node count"
  type        = number
  default     = 2
}

variable "system_vm_size" {
  description = "System VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_node_count" {
  description = "User node count"
  type        = number
  default     = 2
}

variable "user_node_min_count" {
  description = "User node min"
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "User node max"
  type        = number
  default     = 3
}

variable "user_vm_size" {
  description = "User VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "service_cidr" {
  description = "Service CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "DNS Service IP"
  type        = string
  default     = "10.1.0.10"
}