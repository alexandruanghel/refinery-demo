#!/usr/bin/env bash
# Builds the Azure infrastructure

# Local variables
_realpath() { [[ ${1} == /* ]] && echo "${1}" || echo "${PWD}"/"${1#./}"; }
_realpath="$(command -v realpath || echo _realpath )"
_this_script_dir=$(${_realpath} "$(dirname "${BASH_SOURCE[0]}")")
_python="$(command -v python3 || command -v python)"


# Azure cli
echo -e "Configure Azure cli\n----------------------------------------------"
source "${_this_script_dir}/configure_azure_cli.sh"

# Infra
echo -e "Building the Azure Infrastructure\n----------------------------------------------"
echo
source "${_this_script_dir}/scripts/run_terraform.sh" apply \
                     "${_this_script_dir}/terraform/azure" \
                     -var-file="${_this_script_dir}/terraform/demo.tfvars"

#
