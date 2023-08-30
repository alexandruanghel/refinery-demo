### Identities

# Get the users details from the Azure AD Tenant
# Uses ignore_missing to ignore any service principals
data "azuread_users" "project" {
  object_ids     = data.azuread_group.project.members
  ignore_missing = true
}
data "azuread_users" "consumers" {
  object_ids     = data.azuread_group.consumers.members
  ignore_missing = true
}

#resource "databricks_user" "current" {
#  provider     = databricks.azure_account
#  user_name    = data.azuread_user.current.user_principal_name
#  active       = true
#  force        = true
#}

resource "databricks_user" "project" {
  provider     = databricks.azure_account
  count        = length(data.azuread_users.project.users)
  user_name    = data.azuread_users.project.users[count.index].user_principal_name
  display_name = data.azuread_users.project.users[count.index].display_name
  active       = true
  force        = true
}

resource "databricks_user" "consumers" {
  provider     = databricks.azure_account
  count        = length(data.azuread_users.consumers.users)
  user_name    = data.azuread_users.consumers.users[count.index].user_principal_name
  display_name = data.azuread_users.consumers.users[count.index].display_name
  active       = true
  force        = true
}

resource "databricks_group" "project" {
  provider     = databricks.azure_account
  display_name = data.azuread_group.project.display_name
  force        = true
}
resource "databricks_group" "consumers" {
  provider     = databricks.azure_account
  display_name = data.azuread_group.consumers.display_name
  force        = true
}


## Set all of the Databricks groups members
resource "databricks_group_member" "project" {
  provider  = databricks.azure_account
  count     = length(databricks_user.project)
  group_id  = databricks_group.project.id
  member_id = databricks_user.project[count.index].id
}
resource "databricks_group_member" "consumers" {
  provider  = databricks.azure_account
  count     = length(databricks_user.consumers)
  group_id  = databricks_group.consumers.id
  member_id = databricks_user.consumers[count.index].id
}
