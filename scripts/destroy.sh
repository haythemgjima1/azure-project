#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$PROJECT_DIR/terraform"
command -v az >/dev/null || { echo "Azure CLI (az) is required." >&2; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required." >&2; exit 1; }
az account show --output none

RG_NAME="$(terraform -chdir="$TF_DIR" output -raw resource_group_name)"
terraform -chdir="$TF_DIR" destroy

REMAINING="$(az group list --query "[?name=='$RG_NAME'].name" --output tsv)"
if [[ -z "$REMAINING" ]]; then
  echo "PASS: resource group $RG_NAME is absent."
else
  echo "FAIL: resource group $RG_NAME still exists." >&2
  exit 1
fi
