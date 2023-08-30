### Unity Catalog infrastructure

# Deploy the Azure Storage Containers in the account
resource "azurerm_storage_data_lake_gen2_filesystem" "metastore_default" {
  name               = "metastore-default"
  storage_account_id = azurerm_storage_account.main.id
  depends_on         = [azurerm_storage_account.main]
}

resource "azurerm_storage_data_lake_gen2_filesystem" "catalog_default" {
  name               = "catalog-default"
  storage_account_id = azurerm_storage_account.main.id
  depends_on         = [azurerm_storage_account.main]
}

# Access Connector for metastore
resource "azurerm_databricks_access_connector" "metastore_default" {
  name                = "mi-${var.azure_uc_metastore}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  identity {
    type = "SystemAssigned"
  }
  depends_on = [azurerm_resource_group.main]
}

# Assign the "Storage Blob Data Contributor" Role on the Storage Account to the Access Connector
resource "azurerm_role_assignment" "metastore" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.metastore_default.identity[0].principal_id
  depends_on           = [azurerm_storage_account.main, azurerm_databricks_access_connector.metastore_default]
}

# Deploy the Metastore
resource "databricks_metastore" "main" {
  provider     = databricks.azure_account
  name         = var.azure_uc_metastore
  storage_root = format("abfss://%s@%s.dfs.core.windows.net/",
    azurerm_storage_data_lake_gen2_filesystem.metastore_default.name,
    azurerm_storage_account.main.name)
  region = var.azure_location
}

# Metastore default credential
resource "databricks_metastore_data_access" "main" {
  provider     = databricks.azure_account
  metastore_id = databricks_metastore.main.id
  name         = azurerm_databricks_access_connector.metastore_default.name
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.metastore_default.id
  }
  is_default = true
}

# Assign the Metastore to the workspace
resource "databricks_metastore_assignment" "main" {
  provider             = databricks.azure_account
  metastore_id         = databricks_metastore.main.id
  workspace_id         = azurerm_databricks_workspace.main.workspace_id
  default_catalog_name = "main"
  depends_on           = [databricks_metastore.main, azurerm_databricks_workspace.main]
}

# Sync the AD groups with the Databricks Account
#module "databricks_groups_admin" {
#  source                     = "../databricks/databricks-principal"
#  principal_type             = "group"
#  principal_identifier       = data.azuread_group.admin_group.display_name
#}
#
#module "admin_group_sync" {
#  source = "../databricks/ad-groups-sync"
#  groups = [data.azuread_group.admin_group.display_name]
#  depends_on = [module.databricks_groups]
#}

# Make the admin group account_admin
resource "databricks_group_role" "project" {
  provider   = databricks.azure_account
  group_id   = databricks_group.project.id
  role       = "account_admin"
  depends_on = [databricks_group.project]
}

# Assign groups to the workspace
resource "databricks_mws_permission_assignment" "project" {
  provider     = databricks.azure_account
  workspace_id = azurerm_databricks_workspace.main.workspace_id
  principal_id = databricks_group.project.id
  permissions  = ["ADMIN"]
  depends_on   = [databricks_group.project, databricks_metastore_assignment.main]
}
resource "databricks_mws_permission_assignment" "consumers" {
  provider     = databricks.azure_account
  workspace_id = azurerm_databricks_workspace.main.workspace_id
  principal_id = databricks_group.consumers.id
  permissions  = ["USER"]
  depends_on   = [databricks_group.consumers, databricks_metastore_assignment.main]
}

# Data container credential
resource "databricks_storage_credential" "data" {
  name = format("cred_%s_%s",
    azurerm_storage_data_lake_gen2_filesystem.metastore_default.name,
    azurerm_storage_account.main.name)
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.metastore_default.id
  }
  depends_on = [
    databricks_metastore_assignment.main
  ]
}
resource "databricks_grants" "cred_current" {
  storage_credential = databricks_storage_credential.data.id
  grant {
    principal  = data.azuread_user.current.user_principal_name
    privileges = ["ALL_PRIVILEGES"]
  }
}

resource "databricks_grants" "cred_project" {
  storage_credential = databricks_storage_credential.data.id
  grant {
    principal  = databricks_group.project.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
}

# Data external location
resource "databricks_external_location" "data" {
  name = format("loc_%s_%s",
    azurerm_storage_data_lake_gen2_filesystem.metastore_default.name,
    azurerm_storage_account.main.name)
  url = format("abfss://%s@%s.dfs.core.windows.net",
    azurerm_storage_data_lake_gen2_filesystem.data.name,
    azurerm_storage_account.main.name)
  credential_name = databricks_storage_credential.data.id
  comment         = "Managed by TF"
  depends_on      = [databricks_metastore_assignment.main]
}

resource "databricks_grants" "loc_project" {
  external_location = databricks_external_location.data.id
  grant {
    principal  = databricks_group.project.display_name
    privileges = ["ALL_PRIVILEGES"]
  }
}

resource "databricks_grants" "loc_current" {
  external_location = databricks_external_location.data.id
  grant {
    principal  = data.azuread_user.current.user_principal_name
    privileges = ["ALL_PRIVILEGES"]
  }
}

# Catalog
#resource "databricks_catalog" "data" {
#  metastore_id = databricks_metastore.main.id
#  name = var.azure_uc_catalog
#  depends_on      = [
#    databricks_metastore_assignment.main
#  ]
#}
#resource "databricks_schema" "default" {
#  catalog_name = databricks_catalog.data.id
#  name         = "default"
#  comment      = "this schema is managed by terraform"
#  properties = {
#    kind = "various"
#  }
#}

#resource "databricks_grants" "main_project" {
#  catalog = "main"
#  grant {
#    principal  = databricks_group.project.display_name
#    privileges = ["READ_VOLUME, WRITE_VOLUME, EXECUTE, MODIFY, SELECT"]
#  }
#  depends_on      = [databricks_metastore_assignment.main, databricks_mws_permission_assignment.project]
#}
#
#resource "databricks_grants" "cat_current" {
#  catalog = "main"
#  grant {
#    principal  = data.azuread_user.current.user_principal_name
#    privileges = ["USE_CATALOG", "USE_SCHEMA"]
#  }
#  depends_on      = [databricks_metastore_assignment.main]
#}
#
#resource "databricks_grants" "cat_consumers" {
#  catalog = "main"
#  grant {
#    principal  = databricks_group.consumers.display_name
#    privileges = ["USE_CATALOG", "USE_SCHEMA"]
#  }
#  depends_on      = [databricks_metastore_assignment.main, databricks_mws_permission_assignment.consumers]
#}

# Volume
resource "databricks_volume" "libraries" {
  name             = "libraries"
  catalog_name     = "main"
  schema_name      = "default"
  volume_type      = "MANAGED"
}
#
#resource "databricks_grants" "vol_current" {
#  volume = databricks_volume.libraries.id
#  grant {
#    principal  = data.azuread_user.current.user_principal_name
#    privileges = ["ALL_PRIVILEGES"]
#  }
#}
#
#resource "databricks_grants" "vol_project" {
#  volume = databricks_volume.libraries.id
#  grant {
#    principal  = databricks_group.project.display_name
#    privileges = ["ALL_PRIVILEGES"]
#  }
#  depends_on      = [databricks_metastore_assignment.main, databricks_volume.libraries]
#}