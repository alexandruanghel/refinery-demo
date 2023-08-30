#!/usr/bin/env bash

# Required parameters
whl_full_path=${1}
volume_path=${2}
profile=${3}

whl_file=${whl_full_path##*/}
# upload the whl file to Volumes
[ -f "${whl_full_path}" ] || { echo "Wheel file ${whl_full_path} doesn't exit"; exit 1; }
whl_volume_path="${volume_path}/${whl_file}"
whl_dbfs_path="dbfs:${whl_volume_path}"
echo "Uploading the whl to \"${whl_dbfs_path}\""
databricks --profile "${profile}" fs cp "${whl_full_path}" "${whl_dbfs_path}" --overwrite
echo
