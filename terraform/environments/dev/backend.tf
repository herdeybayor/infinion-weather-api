terraform {
  backend "azurerm" {
    resource_group_name  = "herdeybayor4realgmail.com"
    storage_account_name = "tfstatesherifdeen"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}