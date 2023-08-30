#!/usr/bin/env bash
#
# Generates an Azure Active Directory Token of the current az cli login (using 'az account get-access-token').
# If optional positional arguments are used, it will login with those credentials first.
# Returns the access token as a variable called accessToken in the Azure Pipelines format.
#

# Optional parameters - if not set it will use the Databricks Resource ID and the existing CLI login
_azure_resource=${1:-"2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"}
_sp_client_id=${2:-${ARM_CLIENT_ID}}
_sp_client_secret=${3:-${ARM_CLIENT_SECRET}}
_tenant_id=${4:-${ARM_TENANT_ID:-"fd8b4c0b-0fc4-457a-bfe5-c2d245e8944e"}}
_subscription_id=${5:-${ARM_SUBSCRIPTION_ID:-"b08299c7-27d5-48d6-8405-193a7759135c"}}

az version >/dev/null 2>&1 || { echo "Azure cli is not installed"; exit 1; }

# Install the Azure Databricks cli extension
az extension add --name databricks 2> /dev/null || { az extension add --name databricks --debug; exit 1; }

# Log in as service principal with Azure CLI (if parameters were defined)
if [ -n "${_sp_client_id}" ] && [ -n "${_sp_client_secret}" ] && [ -n "${_tenant_id}" ]; then
  echo -e "Will use the Service Principal ${_sp_client_id} and its Secret to authenticate to Azure RM"

  # Log out
  az logout

  # Log in with the details from parameters
  echo -e "Logging in as: ${_sp_client_id}"
  az login --service-principal --username "${_sp_client_id}" --password "${_sp_client_secret}" --tenant "${_tenant_id}" --allow-no-subscriptions || exit 1
else
  az_account=$(az account show)
  [ -z "${az_account}" ] && az login
fi

# Set the Subscription
if [ -n "${_subscription_id}" ]; then
  echo -e "Setting the active subscription to \"${_subscription_id}\""
  az account set --subscription "${_subscription_id}" || exit 1
fi

# Use the az cli command to get the token
echo "Getting the AAD Access Token"
access_token=$(az account get-access-token --resource="${_azure_resource}" --output tsv --query accessToken)
[ -z "${access_token}" ] && exit 1
echo "Got the AAD access token"
