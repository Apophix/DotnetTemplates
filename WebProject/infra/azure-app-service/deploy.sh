#!/usr/bin/env bash
# Deploys all WebProject infrastructure to Azure using a Deployment Stack.
# Creates/updates the stack-webprojectazureprefix deployment stack at subscription scope,
# which owns rg-webprojectazureprefix and all resources within it.
#
# Usage:
#   ./infra/azure-app-service/deploy.sh [--location <region>] [--what-if]
#
# Options:
#   --location <region>   Azure region (default: centralus)
#   --what-if             Validate the deployment without making changes
#
# The SQL admin password is read from the AZURE_SQL_ADMIN_PASSWORD environment
# variable if set, otherwise prompted interactively.
#
# Prerequisites:
#   - az CLI installed and logged in (az login)
#   - Bicep extension: az bicep install

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCATION="centralus"
WHAT_IF=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --location) LOCATION="$2"; shift 2 ;;
    --what-if)  WHAT_IF=true; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# Verify az CLI
if ! command -v az &>/dev/null; then
  echo "ERROR: az CLI not found in PATH" >&2
  exit 1
fi

echo "[DEBUG] az version:"
az version

echo "[DEBUG] az bicep version:"
az bicep version

echo "[DEBUG] Location      : $LOCATION"
echo "[DEBUG] WhatIf        : $WHAT_IF"
echo "[DEBUG] Script dir    : $SCRIPT_DIR"

# Resolve paths
BICEP_FILE="$SCRIPT_DIR/main.bicep"
ARM_FILE="${BICEP_FILE%.bicep}.compiled.json"

if [[ ! -f "$BICEP_FILE" ]]; then
  echo "ERROR: main.bicep not found at $BICEP_FILE" >&2
  exit 1
fi

# Get SQL admin password
if [[ -n "${AZURE_SQL_ADMIN_PASSWORD:-}" ]]; then
  SQL_ADMIN_PASSWORD="$AZURE_SQL_ADMIN_PASSWORD"
else
  read -r -s -p "SQL admin password: " SQL_ADMIN_PASSWORD
  echo
fi

# Compile Bicep -> ARM JSON
echo "[DEBUG] Compiling: $BICEP_FILE"
az bicep build --file "$BICEP_FILE" --outfile "$ARM_FILE"
echo "[DEBUG] Compiled to: $ARM_FILE"

# Cleanup ARM file on exit
trap 'rm -f "$ARM_FILE"; echo "[DEBUG] Cleaned up: $ARM_FILE"' EXIT

STACK_NAME="stack-webprojectazureprefix"
PARAMS=(
  "location=$LOCATION"
  "staticWebAppLocation=$LOCATION"
  "sqlAdminLogin=sqladmin"
  "sqlAdminPassword=$SQL_ADMIN_PASSWORD"
)

if [[ "$WHAT_IF" == "true" ]]; then
  echo "Validating WebProject deployment stack..."
  az deployment-stacks sub validate \
    --name "$STACK_NAME" \
    --location "$LOCATION" \
    --template-file "$ARM_FILE" \
    --parameters "${PARAMS[@]}" \
    --deny-settings-mode none \
    --output table
else
  echo "Deploying WebProject infrastructure..."
  az deployment-stacks sub create \
    --name "$STACK_NAME" \
    --location "$LOCATION" \
    --template-file "$ARM_FILE" \
    --parameters "${PARAMS[@]}" \
    --deny-settings-mode none \
    --action-on-unmanage detachAll \
    --yes \
    --output table
fi

echo "Deployment complete."
