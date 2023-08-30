#!/usr/bin/env bash
#
# Retrieves Databricks workspace details, including the Url
#
# Bash settings
set -o pipefail

# Required parameters
_resource_group_name=${1}
_workspace_name=${2}

# Optional parameters
_subscription_id=${3}

# Local variables
_python="$(command -v python3 || command -v python)"

_usage() {
  echo -e "Usage: ${0} <resource_group_name> <workspace_name>"
  exit 1
}

# Parameters check
[ -z "${_resource_group_name}" ] && _usage
[ -z "${_workspace_name}" ] && _usage
if [ -n "${_subscription_id}" ]; then
  echo "Using subscription ${_subscription_id}"
  az account set --subscription "${_subscription_id}" || exit 1
fi

# Use the az cli command
echo -e "Getting the details of workspace '${_workspace_name}' from resource group '${_resource_group_name}'"
_response=$(az resource show --name "${_workspace_name}" \
                             --resource-type "Microsoft.Databricks/workspaces" \
                             --resource-group "${_resource_group_name}" \
                             --output json \
                             --query "{id:id, name:name, resourceGroup:resourceGroup, location:location, workspaceId:properties.workspaceId, workspaceUrl:properties.workspaceUrl}")
echo "${_response}"
[ -z "${_response}" ] && exit 1

# Get the Databricks workspace Url from response
workspace_hostname=$(echo "${_response}" | ${_python} -c 'import sys,json; print(json.load(sys.stdin)["workspaceUrl"])')
[ -z "${workspace_hostname}" ] && { echo "${_response}" >&2; exit 1; }
workspace_url="https://${workspace_hostname}"
echo -e "Got the workspace Url: '${workspace_url}'"

# Get the Databricks workspace Resource Id from response
workspace_id=$(echo "${_response}" | ${_python} -c 'import sys,json; print(json.load(sys.stdin)["workspaceId"])')
[ -z "${workspace_id}" ] && { echo "${_response}" >&2; exit 1; }
echo -e "Got the workspace Id: '${workspace_id}'"

# Get the Databricks workspace Location from response
workspace_loc=$(echo "${_response}" | ${_python} -c 'import sys,json; print(json.load(sys.stdin)["location"])')
[ -z "${workspace_loc}" ] && { echo "${_response}" >&2; exit 1; }
echo -e "Got the workspace Location: '${workspace_loc}'"

# Pass the variables to Azure Pipelines
if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  [ -n "${workspace_id}" ] && echo "##vso[task.setvariable variable=databricksWorkspaceId;issecret=false]${workspace_id}"
  [ -n "${workspace_hostname}" ] && echo "##vso[task.setvariable variable=databricksWorkspaceHostname;issecret=false]${workspace_hostname}"
  [ -n "${workspace_url}" ] && echo "##vso[task.setvariable variable=databricksWorkspaceUrl;issecret=false]${workspace_url}"
  [ -n "${workspace_loc}" ] && echo "##vso[task.setvariable variable=databricksWorkspaceLocation;issecret=false]${workspace_loc}"
fi
