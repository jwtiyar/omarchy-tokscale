#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/omarchy/plugins/jwty.tokscale"

echo "Installing Tokscale plugin to ${TARGET_DIR}..."
mkdir -p "${TARGET_DIR}"

cp "${SCRIPT_DIR}/manifest.json" "${TARGET_DIR}/"
cp "${SCRIPT_DIR}/BarWidget.qml" "${TARGET_DIR}/"
cp "${SCRIPT_DIR}/status.sh" "${TARGET_DIR}/"
cp "${SCRIPT_DIR}/open-tokscale.sh" "${TARGET_DIR}/"
chmod +x "${TARGET_DIR}/status.sh" "${TARGET_DIR}/open-tokscale.sh"

echo "Validating plugin..."
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "${TARGET_DIR}"
  echo "Validation passed."
  echo "Restarting Omarchy shell..."
  omarchy restart shell || true
fi

echo "Successfully installed! Add 'jwty.tokscale' to bar.layout.right in ~/.config/omarchy/shell.json if needed."
