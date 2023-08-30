#!/usr/bin/env bash

# Upload to Azure
landing_storage_account="demorefinerystorage2"
landing_path="data/landing"

az storage blob upload-batch -d "${landing_path}" --account-name "${landing_storage_account}" -s uploaded_data/ --auth-mode login --overwrite

