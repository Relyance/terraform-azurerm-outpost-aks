terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "5.12.0" }
  }
}
provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  features {}
}
