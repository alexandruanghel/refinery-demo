#!/usr/bin/env bash
#
# Installs the new Databricks cli and configures it with the account and workspace profiles
#
# Bash settings
set -o pipefail

# Required parameters
_account_id=${1-${DATABRICKS_ACCOUNT_ID}}
_workspace_url=${2-${DATABRICKS_WORKSPACE_URL}}

# Local variables
_cli_profile_name=${DATABRICKS_CLI_PROFILE-"DEFAULT"}
_cli_version=${DATABRICKS_CLI_VERSION-"0.203.2"}
_sed="$(command -v gsed || command -v sed)"

_usage() {
  echo -e "Usage: ${0} <account_id> <workspace_url>"
  exit 1
}

# Parameters check
[ -z "${_account_id}" ] && [ -z "${_workspace_url}" ] && _usage

# Install the Databricks CLI
# downloaded from https://github.com/databricks/setup-cli/blob/main/install.sh

VERSION=${_cli_version}

if [[ $(databricks version | cut -d'v' -f2) != "${VERSION}" ]]; then
  echo "Installing databricks cli version ${VERSION}"
  FILE="databricks_cli_$VERSION"

  # Include operating system in file name.
  OS="$(uname -s | cut -d '-' -f 1)"
  case "$OS" in
  Linux)
      FILE="${FILE}_linux"
      TARGET="/usr/local/bin"
      ;;
  Darwin)
      FILE="${FILE}_darwin"
      TARGET="/usr/local/bin"
      ;;
  MINGW64_NT)
      FILE="${FILE}_windows"
      TARGET="/c/Windows"
      ;;
  *)
      echo "Unknown operating system: $OS"
      exit 1
      ;;
  esac

  # Include architecture in file name.
  ARCH="$(uname -m)"
  case "$ARCH" in
  i386)
      FILE="${FILE}_386"
      ;;
  x86_64)
      FILE="${FILE}_amd64"
      ;;
  arm)
      FILE="${FILE}_arm"
      ;;
  arm64|aarch64)
      FILE="${FILE}_arm64"
      ;;
  *)
      echo "Unknown architecture: $ARCH"
      exit 1
      ;;
  esac

  # Make sure the target directory is writable.
  if [ ! -w "$TARGET" ]; then
      echo "Target directory $TARGET is not writable."
      echo "Please run this script through sudo to allow writing to $TARGET."
      exit 1
  fi

  # Make sure we don't overwrite an existing installation.
  if [ -f "$TARGET/databricks" ]; then
      echo "Target path $TARGET/databricks already exists."
      exit 1
  fi

  # Change into temporary directory.
  tmpdir="$(mktemp -d)"
  cd "$tmpdir"

  # Download release archive.
  curl -L -s -O "https://github.com/databricks/cli/releases/download/v${VERSION}/${FILE}.zip"

  # Unzip release archive.
  unzip -q "${FILE}.zip"

  # Add databricks to path.
  chmod +x ./databricks
  cp ./databricks "$TARGET"
  echo "Installed $($TARGET/databricks -v) at $TARGET/databricks."

  # Clean up temporary directory.
  cd "$OLDPWD"
  rm -rf "$tmpdir" || true

  # Check
  [[ $(databricks version | cut -d'v' -f2) == "${VERSION}" ]] || { echo "Error: Databricks CLI version is not ${VERSION}" >&2; exit 1; }
fi

# Configure the databricks profiles

# Configure the databricks-cli account profile
if [ -n "${_account_id}" ]; then
  echo "Configuring the cli with account_id '${_account_id}'"
  # delete the previous ACCOUNT section
  ${_sed} -i "/^\[ACCOUNT\]/,/^\[/{/^\[/!d;};{/^\[ACCOUNT\]/d;}" ~/.databrickscfg
  {
    echo "[ACCOUNT]"
    echo "host = https://accounts.azuredatabricks.net"
    echo "account_id = ${_account_id}"
  } >> ~/.databrickscfg

  echo -e "Printing the configured profile using 'databricks auth env':"
  databricks auth env --profile ACCOUNT || exit 1
  echo
fi

# Configure the databricks-cli workspace profile
if [ -n "${_workspace_url}" ]; then
  echo "Configuring the cli profile '${_cli_profile_name}' with workspace url '${_workspace_url}'"
  # delete the previous profile section
  ${_sed} -i "/^\[${_cli_profile_name}\]/,/^\[/{/^\[/!d;};{/^\[${_cli_profile_name}\]/d;}" ~/.databrickscfg
  {
    echo "[${_cli_profile_name}]"
    echo "host = ${_workspace_url}"
  } >> ~/.databrickscfg

  echo -e "Printing the configured profile using 'databricks auth env':"
  databricks auth env --profile "${_cli_profile_name}" || exit 1
  echo
fi

echo -e "\nShowing the content of the ~/.databrickscfg file:"
cat ~/.databrickscfg

echo
echo -e "\nShowing the configured profiles using 'databricks auth profiles':"
databricks auth profiles --log-level DEBUG
