#!/usr/bin/env bash
# WebProject — One-time bootstrap for Azure infrastructure.
#
# Run this ONCE before the first deployment. Registers resource providers,
# sets GitHub secrets, and deploys the initial infrastructure stack.
#
# Prerequisites:
#   - az CLI installed and logged in (az login) with Contributor on the subscription
#   - gh CLI installed and authenticated to the GitHub repo
#   - Bicep extension: az bicep install
#
# Usage:
#   ./infra/bootstrap.sh --variant <app-service|container-apps> [--location <region>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCATION="centralus"
VARIANT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant)  VARIANT="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$VARIANT" ]]; then
  echo "ERROR: --variant is required (app-service or container-apps)" >&2
  exit 1
fi

if [[ "$VARIANT" != "app-service" && "$VARIANT" != "container-apps" ]]; then
  echo "ERROR: --variant must be 'app-service' or 'container-apps'" >&2
  exit 1
fi

echo "WebProject Bootstrap"
echo "===================="
echo "Variant : ${VARIANT}"
echo "Location: ${LOCATION}"
echo ""

# ── Preflight checks ──────────────────────────────────────────────────────────

if ! command -v az &>/dev/null; then
  echo "ERROR: az CLI not found. Install from https://aka.ms/installazurecliwindows" >&2
  exit 1
fi
if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found. Install from https://cli.github.com" >&2
  exit 1
fi
if ! az account show &>/dev/null; then
  echo "ERROR: Not logged in to Azure. Run: az login" >&2
  exit 1
fi
if ! gh auth status &>/dev/null; then
  echo "ERROR: Not logged in to GitHub. Run: gh auth login" >&2
  exit 1
fi

echo "✓ Preflight checks passed"
echo ""

# ── SQL admin password ────────────────────────────────────────────────────────

if [[ -n "${AZURE_SQL_ADMIN_PASSWORD:-}" ]]; then
  SQL_ADMIN_PASSWORD="$AZURE_SQL_ADMIN_PASSWORD"
  echo "✓ SQL admin password read from AZURE_SQL_ADMIN_PASSWORD env var"
else
  read -r -s -p "SQL admin password: " SQL_ADMIN_PASSWORD
  echo
fi

# ── Set GitHub Actions secret ─────────────────────────────────────────────────

echo "Setting AZURE_SQL_ADMIN_PASSWORD as a GitHub Actions secret..."
echo "${SQL_ADMIN_PASSWORD}" | gh secret set AZURE_SQL_ADMIN_PASSWORD
echo "✓ GitHub secret set"
echo ""

# ── Register required resource providers ─────────────────────────────────────

echo "Registering required Azure resource providers..."
az provider register -n Microsoft.Web --wait
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerRegistry --wait
echo "✓ Resource providers registered"
echo ""

# ── Compile and deploy Bicep ──────────────────────────────────────────────────

if [[ "$VARIANT" == "app-service" ]]; then
  VARIANT_DIR="azure-app-service"
else
  VARIANT_DIR="azure-container-apps"
fi

BICEP_FILE="${SCRIPT_DIR}/${VARIANT_DIR}/main.bicep"
ARM_FILE="${BICEP_FILE%.bicep}.compiled.json"
trap 'rm -f "$ARM_FILE"' EXIT

echo "Compiling Bicep..."
az bicep build --file "$BICEP_FILE" --outfile "$ARM_FILE"
echo "✓ Compiled"
echo ""

echo "Deploying infrastructure stack (this takes ~5-10 minutes)..."
az stack sub create \
  --name stack-webprojectazureprefix \
  --location "${LOCATION}" \
  --template-file "${ARM_FILE}" \
  --parameters \
    location="${LOCATION}" \
    staticWebAppLocation="${LOCATION}" \
    sqlAdminLogin=sqladmin \
    sqlAdminPassword="${SQL_ADMIN_PASSWORD}" \
  --deny-settings-mode none \
  --action-on-unmanage detachAll \
  --yes \
  --output table

echo ""
echo "✓ Infrastructure deployed"
echo ""

# ── Next steps ────────────────────────────────────────────────────────────────

echo "========================================"
echo "Bootstrap complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Push a commit to main to trigger the first full deployment:"
echo "     git commit --allow-empty -m 'chore: trigger first container deployment'"
echo "     git push"
echo ""
echo "  2. Watch the pipeline at:"
echo "     https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
echo ""
echo "  From now on, all infrastructure changes via PR to infra/** are deployed"
echo "  automatically by infra.yml. All app deploys trigger via push to main."
