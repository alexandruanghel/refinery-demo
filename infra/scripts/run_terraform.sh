#!/usr/bin/env bash
# Runs all Terraform commands on a directory.

# Debug
#set -x
#export TF_LOG="DEBUG"

_usage() {
  echo "Usage: ${0} {apply|destroy} path"
  exit 1
}

_cd_dir() {
  # Go to the Terraform dir
  local tf_path="${1}"
  if [ -z "${tf_path}" ]; then
    echo "ERROR: No path given"
    _usage
    exit 1
  fi
  if [ -d "${tf_path}" ]; then
    cd "${tf_path}" || exit 1
  else
    echo -e "ERROR: Terraform folder ${tf_path} doesn't exist"
    exit 1
  fi
}

_apply() {
  # Go to the Terraform dir
  _cd_dir "${1}"

  # Shift input parameters by 1
  shift 1

  # Run terraform init
  echo -e "Running terraform init with local backend\n----------------------"
  terraform init -upgrade=true || exit 1

  # Run terraform validate
  echo -e "\nRunning terraform validate\n----------------------"
  terraform validate || exit 1

  # Run terraform plan (and remove -auto-approve from the list of arguments)
  echo -e "\nRunning terraform plan\n----------------------"
  plan_args="$(for arg in "$@"; do echo "${arg}" | grep -v "\-auto-approve"; done)"
  terraform plan ${plan_args} -out=tfplan.out || exit 1

  # Run terraform apply (and remove -var-file from the list of arguments since it's contained in the plan)
  echo -e "\nRunning terraform apply\n----------------------"
  apply_args="$(for arg in "$@"; do echo "${arg}" | grep -v "\-var"; done)"
  terraform apply ${apply_args} tfplan.out || exit 1
  [ -e "tfplan.out" ] && unlink "tfplan.out"
  echo -n
}

_destroy() {
  # Go to the Terraform dir
  _cd_dir "${1}"

  # Shift input parameters by 1
  shift 1

  # Run terraform destroy
  echo -e "Running terraform destroy\n----------------------"
  terraform destroy "$@" || exit 1

  # Clean terraform files
  echo -e "\nCleaning terraform files\n----------------------"
  echo -e "Removing .terraform" && [ -e ".terraform" ] && rm -rf ".terraform"
  echo -e "Removing .terraform.lock.hcl" && [ -e ".terraform.lock.hcl" ] && unlink ".terraform.lock.hcl"
  echo -e "Removing terraform.tfstate" && [ -e "terraform.tfstate" ] && unlink "terraform.tfstate"
  echo -e "Removing terraform.tfstate.backup" && [ -e "terraform.tfstate.backup" ] && unlink "terraform.tfstate.backup"
  echo -e "Removing crash.log" && [ -e "crash.log" ] && unlink "crash.log"
  echo -e "Removing tfplan.out" && [ -e "tfplan.out" ] && unlink "tfplan.out"
  echo -n
}

case "${1}" in
  apply)
    echo
    shift 1
    _apply "$@"
    ;;
  destroy)
    echo
    shift 1
    _destroy "$@"
    ;;
  *)
    _usage
    ;;
esac
