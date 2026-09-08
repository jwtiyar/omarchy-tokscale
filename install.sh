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

  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi

  SECTION="right"
  if [ -t 0 ]; then
    if command -v gum >/dev/null 2>&1; then
      SECTION=$(printf '%s\n' right center left | gum choose --header="Place Tokscale in which bar section?" --selected="right") || SECTION="right"
    else
      echo ""
      echo -n "Place Tokscale in which bar section? (right / center / left) [default: right]: "
      read -r input_section
      if [[ "$input_section" == "left" || "$input_section" == "center" || "$input_section" == "right" ]]; then
        SECTION="$input_section"
      fi
    fi
  fi

  echo "Enabling Tokscale in the ${SECTION} section of the bar..."
  omarchy plugin enable jwty.tokscale --section "${SECTION}" || true
  echo "Installed and enabled on the ${SECTION} section of the bar."
else
  echo "Installed to ${TARGET_DIR}."
  echo "Add 'jwty.tokscale' to bar.layout in ~/.config/omarchy/shell.json."
fi
