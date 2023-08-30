#!/usr/bin/env bash

# Local variables
_realpath() { [[ ${1} == /* ]] && echo "${1}" || echo "${PWD}"/"${1#./}"; }
_realpath="$(command -v realpath || echo _realpath )"
_this_script_dir=$(${_realpath} "$(dirname "${BASH_SOURCE[0]}")")
_libs_dir="${_this_script_dir}/../library/lakehousePipelines"
profile="AZURE"

# git clone


# Build wheel
source "${_this_script_dir}/build_wheel.sh" "${_libs_dir}" || exit 1
whl_full_path="${whl_full_path}"
volume_path="/Volumes/main/default/libraries"

# Upload wheel
source "${_this_script_dir}/upload_wheel.sh" "${whl_full_path}" "${volume_path}" "${profile}" || exit 1

# Launch job
all_job_json='{
    "name": "Lakehouse Refinery - Scheduled",
    "format": "MULTI_TASK",
    "tasks": [
        {
            "task_key": "bronze_countries",
            "run_if": "ALL_SUCCESS",
            "python_wheel_task": {
                "package_name": "lakehousePipelines",
                "entry_point": "bronze_countries",
                "named_parameters": {
                    "sourceBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/landing",
                    "pipelineBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/data",
                    "pipelineDatabase": "main.default"
                }
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "libraries": [
                {
                    "whl": "/Volumes/main/default/libraries/lakehousePipelines-0.0.1-py3-none-any.whl"
                }
            ],
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        },
        {
            "task_key": "bronze_customers",
            "run_if": "ALL_SUCCESS",
            "python_wheel_task": {
                "package_name": "lakehousePipelines",
                "entry_point": "bronze_customers",
                "named_parameters": {
                    "sourceBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/landing",
                    "pipelineBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/data",
                    "pipelineDatabase": "main.default"
                }
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "libraries": [
                {
                    "whl": "/Volumes/main/default/libraries/lakehousePipelines-0.0.1-py3-none-any.whl"
                }
            ],
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        },
        {
            "task_key": "bronze_fraud_reports",
            "run_if": "ALL_SUCCESS",
            "python_wheel_task": {
                "package_name": "lakehousePipelines",
                "entry_point": "bronze_fraud_reports",
                "named_parameters": {
                    "sourceBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/landing",
                    "pipelineBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/data",
                    "pipelineDatabase": "main.default"
                }
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "libraries": [
                {
                    "whl": "/Volumes/main/default/libraries/lakehousePipelines-0.0.1-py3-none-any.whl"
                }
            ],
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        },
        {
            "task_key": "bronze_transactions",
            "run_if": "ALL_SUCCESS",
            "python_wheel_task": {
                "package_name": "lakehousePipelines",
                "entry_point": "bronze_transactions",
                "named_parameters": {
                    "sourceBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/landing",
                    "pipelineBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/data",
                    "pipelineDatabase": "main.default"
                }
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "libraries": [
                {
                    "whl": "/Volumes/main/default/libraries/lakehousePipelines-0.0.1-py3-none-any.whl"
                }
            ],
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        },
        {
            "task_key": "joined_silver_transactions",
            "depends_on": [
                {
                    "task_key": "bronze_transactions"
                },
                {
                    "task_key": "bronze_fraud_reports"
                }
            ],
            "run_if": "ALL_SUCCESS",
            "python_wheel_task": {
                "package_name": "lakehousePipelines",
                "entry_point": "silver_transactions",
                "named_parameters": {
                    "pipelineBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/data",
                    "pipelineDatabase": "main.default"
                }
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "libraries": [
                {
                    "whl": "/Volumes/main/default/libraries/lakehousePipelines-0.0.1-py3-none-any.whl"
                }
            ],
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        },
        {
            "task_key": "silver_countries",
            "depends_on": [
                {
                    "task_key": "bronze_countries"
                }
            ],
            "run_if": "ALL_SUCCESS",
            "python_wheel_task": {
                "package_name": "lakehousePipelines",
                "entry_point": "silver_countries",
                "named_parameters": {
                    "pipelineBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/data",
                    "pipelineDatabase": "main.default"
                }
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "libraries": [
                {
                    "whl": "/Volumes/main/default/libraries/lakehousePipelines-0.0.1-py3-none-any.whl"
                }
            ],
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        },
        {
            "task_key": "silver_customers",
            "depends_on": [
                {
                    "task_key": "bronze_customers"
                }
            ],
            "run_if": "ALL_SUCCESS",
            "python_wheel_task": {
                "package_name": "lakehousePipelines",
                "entry_point": "silver_customers",
                "named_parameters": {
                    "pipelineBasePath": "abfss://data@demorefinerystorage2.dfs.core.windows.net/data",
                    "pipelineDatabase": "main.default"
                }
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "libraries": [
                {
                    "whl": "/Volumes/main/default/libraries/lakehousePipelines-0.0.1-py3-none-any.whl"
                }
            ],
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        },
        {
            "task_key": "gold_aggregations",
            "depends_on": [
                {
                    "task_key": "silver_countries"
                },
                {
                    "task_key": "silver_customers"
                },
                {
                    "task_key": "joined_silver_transactions"
                }
            ],
            "run_if": "ALL_SUCCESS",
            "notebook_task": {
                "notebook_path": "/Shared/Refinery/Gold Aggregations",
                "base_parameters": {
                    "database": "main.default"
                },
                "source": "WORKSPACE"
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        },
        {
            "task_key": "shares",
            "depends_on": [
                {
                    "task_key": "gold_aggregations"
                }
            ],
            "run_if": "ALL_SUCCESS",
            "notebook_task": {
                "notebook_path": "/Shared/Refinery/Shares",
                "base_parameters": {
                    "database": "main.default"
                },
                "source": "WORKSPACE"
            },
            "existing_cluster_id": "0830-053503-vaod58u6",
            "timeout_seconds": 0,
            "email_notifications": {},
            "notification_settings": {
                "no_alert_for_skipped_runs": false,
                "no_alert_for_canceled_runs": false,
                "alert_on_last_attempt": false
            }
        }

    ]
  }
'

databricks --profile "${profile}" jobs create --json "${all_job_json}"
