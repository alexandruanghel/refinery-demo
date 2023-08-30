#!/usr/bin/env bash
#
# Runs all:
#  builds the Azure core infrastructure
#  builds the Azure infrastructure for the data pipeline and project
#  bootstraps the Databricks workspace
#  launches an Azure Data Factory data pipeline that uses Databricks
#


# Local variables
_realpath() { [[ ${1} == /* ]] && echo "${1}" || echo "${PWD}"/"${1#./}"; }
_realpath="$(command -v realpath || echo _realpath )"
_this_script_dir=$(${_realpath} "$(dirname "${BASH_SOURCE[0]}")")
_wait_time=1800   # 30 minutes
_python="$(command -v python || command -v python3)"




# Import variables
source "${_this_script_dir}/scripts/vars.sh" || exit 1

base_local_path=${BASE_LOCAL_PATH:-"/tmp/hybrid-cloud-demo"}


# Prep local environment
echo -e "Preparing the local environment\n----------------------------------------------"
echo

venv_path="${_this_script_dir}/.venv"
${_python} -m venv "${venv_path}"
source "${venv_path}"/bin/activate
pip install -r "${_this_script_dir}"/requirements.txt

downloaded_data_path="${base_local_path}/downloaded_data"
landing_data_path="${base_local_path}/landing_data"
pipeline_data_path="${base_local_path}/pipeline"
pipeline_code_path="${_this_script_dir}/pipeline/lakehousePipelines/lakehousePipelines"



# Infra
echo
echo
echo -e "Building the Azure Infrastructure\n----------------------------------------------"
echo
source "${_this_script_dir}/scripts/build_infra_azure.sh"

exit 1

# Prep data
source "${_this_script_dir}/scripts/download_data.sh" "${downloaded_data_path}"

mkdir -p "${landing_data_path}" || exit 1
[[ -d "${landing_data_path}"/country_code ]] || cp -a "${downloaded_data_path}/fsi/fraud-transaction/country_code" "${landing_data_path}/" || exit 1

if ! ls "${landing_data_path}"/transactions/*.json.gz > /dev/null; then
  spark-submit \
    --packages io.delta:delta-core_2.12:2.2.0 \
    --driver-memory 4g \
    "${_this_script_dir}/scripts/prep_data.py" \
    --downloadedPath "${downloaded_data_path}" \
    --landingPath "${landing_data_path}"
fi


# Run landing to bronze
if [[ ! -d "${pipeline_data_path}"/bronze/customers.delta/_delta_log ]]; then
  spark-submit \
    --packages io.delta:delta-core_2.12:2.2.0 \
    --driver-memory 4g \
    "${pipeline_code_path}/bronze_batch.py" \
    --sourceBasePath "${landing_data_path}" \
    --pipelineBasePath "${pipeline_data_path}" \
    --pipelineDatabase test123
fi


# Run the admin setup
# source "${_this_script_dir}/admin/setup-with-terraform.sh"

# Wait until the secret is active
# echo -e "Sleeping for 2 minutes to allow enough time for the client secret to propagate\n----------------------------------------------"
# sleep 120
# echo

# Install the Azure DevOps cli extension
# az extension add --name azure-devops 2> /dev/null || { az extension add --name azure-devops --debug; exit 1; }

# Run the infra pipeline
# echo -e "Running the infra pipeline \"${AZURE_DEVOPS_INFRA_PIPELINE_NAME}\"\n----------------------------------------------"
# _run_id_infra=$(az pipelines run --name "${AZURE_DEVOPS_INFRA_PIPELINE_NAME}" --organization "${AZURE_DEVOPS_ORG_URL}" --project "${AZURE_DEVOPS_PROJECT_NAME}" --query id)
# [ -z "${_run_id_infra}" ] && exit 1
# echo

# Run the data pipeline
# echo -e "Running the data pipeline \"${AZURE_DEVOPS_DATA_PIPELINE_NAME}\"\n----------------------------------------------"
