### Azure infrastructure

# Deploy the Azure Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.azure_resource_group
  location = var.azure_location
}

resource "azurerm_role_assignment" "owners" {
  for_each             = toset([data.azuread_group.project.object_id, data.azurerm_client_config.current.object_id])
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Owner"
  principal_id         = each.value
  depends_on           = [azurerm_resource_group.main]
}

# Deploy the Azure Data Lake Gen 2 Storage Account
resource "azurerm_storage_account" "main" {
  name                      = var.azure_storage_account
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  access_tier               = "Hot"
  is_hns_enabled            = true
  enable_https_traffic_only = true
  depends_on                = [azurerm_resource_group.main]
}

resource "azurerm_storage_data_lake_gen2_filesystem" "data" {
  name               = "data"
  storage_account_id = azurerm_storage_account.main.id
  depends_on         = [azurerm_storage_account.main]
}

# Assign the "Storage Blob Data Contributor" Role on the Storage Account
resource "azurerm_role_assignment" "blob_contributors" {
  for_each             = toset([data.azuread_group.project.object_id, data.azurerm_client_config.current.object_id])
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
  depends_on           = [azurerm_storage_account.main]
}

# Deploy the Azure Databricks workspace
resource "azurerm_databricks_workspace" "main" {
  name                = var.azure_databricks_workspace_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "trial"
}
