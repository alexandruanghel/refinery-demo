#!/usr/bin/env bash
# Builds a wheel

# Required parameters
_libs_dir=${1}

cd "${_libs_dir}" || exit 1
python -m build --wheel
cd dist || exit 1
wheel_file=$(ls -tr *.whl|tail -1)
whl_full_path="${_libs_dir}/dist/${wheel_file}"
echo "Wheel file is: ${whl_full_path}"
