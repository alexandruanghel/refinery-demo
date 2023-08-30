/**
* Builds the Azure infrastructure for the data pipeline and project.
*/

# Providers
terraform {
  required_version = "~> 1.5"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.24"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "databricks" {
  alias      = "azure_account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = "c18993a9-f994-4bd5-8a9d-d0299d0cf90d"
  auth_type  = "azure-cli"
}

# Data Sources
# Azure cli user
data "azurerm_client_config" "current" {}
data "azuread_user" "current" {
  object_id = data.azurerm_client_config.current.object_id
}

# Azure project groups
data "azuread_group" "project" {
  display_name     = var.azure_project_group
  security_enabled = true
}
data "azuread_group" "consumers" {
  display_name     = var.azure_consumers_group
  security_enabled = true
}



output "azure_infrastructure" {
  value = {
    resource_group_id            = azurerm_resource_group.main.id
    resource_group_name          = azurerm_resource_group.main.name
    project_group_object_id      = data.azuread_group.project.object_id
    data_lake_storage_account_id = azurerm_storage_account.main.id
  }
}


output "databricks" {
  value = {
    connector_id  = azurerm_databricks_access_connector.metastore_default.id
    workspace_id  = azurerm_databricks_workspace.main.workspace_id
    workspace_url = azurerm_databricks_workspace.main.workspace_url
  }
}
