#!/usr/bin/env bash

# Upload to Azure
landing_bucket="s3://databricks-workspace-stack-8db8c-metastore-bucket/landing/"

aws s3 cp --recursive uploaded_data "${landing_bucket}"

