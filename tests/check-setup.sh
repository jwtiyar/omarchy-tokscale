#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}"
EVIDENCE_DIR="$(mktemp -d /tmp/tokscale-setup-evidence.XXXXXX)"
CONFIG_DIR="${EVIDENCE_DIR}/config"
trap 'rm -rf "${CONFIG_DIR}"' EXIT
mkdir -p "${CONFIG_DIR}/plugin" "${CONFIG_DIR}/home/.local/bin"
ln -s "${SHELL_DIR}/Commons" "${CONFIG_DIR}/Commons"
ln -s "${SHELL_DIR}/Ui" "${CONFIG_DIR}/Ui"
cp "${REPO_DIR}/BarWidget.qml" "${REPO_DIR}/status.sh" "${CONFIG_DIR}/plugin/"

# Hide any real global CLI from lookup so the check cannot read the user's token data.
cat > "${CONFIG_DIR}/lookup.sh" <<'LOOKUP'
command() {
  if [[ "${1:-}" == -v && "${2:-}" == tokscale ]]; then
    [[ -x "${HOME}/.local/bin/tokscale" ]]
  else
    builtin command "$@"
  fi
}
LOOKUP

# The CLI starts absent. This fixture simulates installing it without reading user data.
cat > "${CONFIG_DIR}/home/.local/bin/tokscale.pending" <<'CLI'
#!/usr/bin/env bash
if [[ "${1:-}" == antigravity ]]; then exit 0; fi
echo '{"totalInput":1000,"totalOutput":500,"totalCost":0.25,"totalMessages":1,"entries":[]}'
CLI
chmod +x "${CONFIG_DIR}/home/.local/bin/tokscale.pending"

cat > "${CONFIG_DIR}/shell.qml" <<'QML'
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "plugin" as Plugin

ShellRoot {
  PanelWindow {
    visible: true
    implicitWidth: 400
    implicitHeight: 40
    Plugin.BarWidget { id: widget }
  }
  Process {
    id: installFixture
    command: ["mv", Quickshell.env("HOME") + "/.local/bin/tokscale.pending",
                    Quickshell.env("HOME") + "/.local/bin/tokscale"]
  }
  TestCase {
    name: "TokscaleSetup"
    when: true
    property string savedClipboard: ""
    function initTestCase() { savedClipboard = Quickshell.clipboardText }
    function cleanupTestCase() { Quickshell.clipboardText = savedClipboard }
    function check(condition, message) {
      if (!condition) {
        console.error("SETUP CHECK FAIL: " + message)
        throw new Error(message)
      }
    }
    function test_setup_and_recovery() {
      tryCompare(widget, "errorMessage", "tokscale not found in PATH", 5000)
      check(widget.barText === "Tokscale setup required", "Missing CLI needs a setup label")
      check(widget.tooltipText.indexOf("installation instructions") !== -1, "Tooltip needs setup guidance")
      widget.totalTokens = 42
      check(widget.barText === "Tokscale setup required", "Stale totals must not hide setup")

      const barButton = findChild(widget, "tokscaleBarButton")
      check(barButton !== null, "Bar button exists")
      mouseClick(barButton, barButton.width / 2, barButton.height / 2)
      tryCompare(widget, "opened", true)
      const banner = findChild(widget, "tokscaleErrorBanner")
      const copyButton = findChild(widget, "copyInstallCommand")
      check(copyButton !== null && copyButton.visible, "Copy action is visible")
      wait(200)
      check(banner.width > 0 && banner.height > 0, "Setup banner has a rendered size")
      let card = banner.parent
      while (card && !("borderSpec" in card)) card = card.parent
      check(card !== null, "Native popup card exists")
      let saved = false
      card.grabToImage(function(result) {
        saved = result.saveToFile(Quickshell.env("SETUP_EVIDENCE_DIR") + "/setup.png")
      })
      tryVerify(function() { return saved }, 5000)

      Quickshell.clipboardText = "before copy"
      mouseClick(copyButton, copyButton.width / 2, copyButton.height / 2)
      check(Quickshell.clipboardText === "npm install -g tokscale", "Copy action writes the exact command")
      check(copyButton.text === "Copied", "Copy action confirms success")
      const keys = findChild(widget, "tokscalePanelKeys")
      parent = keys
      keys.forceActiveFocus()
      wait(100)
      keyClick(Qt.Key_Tab)
      tryCompare(copyButton, "activeFocus", true, 1000)
      check(copyButton.activeFocus, "Copy action is reachable by keyboard")
      Quickshell.clipboardText = "before keyboard copy"
      keyClick(Qt.Key_Return)
      tryCompare(Quickshell, "clipboardText", "npm install -g tokscale", 1000)
      check(Quickshell.clipboardText === "npm install -g tokscale", "Keyboard activates copy")
      keyClick(Qt.Key_Escape)
      tryCompare(widget, "opened", false)
      widget.launchApp()
      check(widget.opened, "Missing-CLI TUI shortcut opens setup instructions")

      widget.parseStatus('{"error":"pricing cache not found"}')
      check(!widget.missingCli && widget.hasError, "Unrelated errors remain errors")
      check(!copyButton.visible, "Install action is hidden for unrelated errors")

      installFixture.running = true
      tryCompare(installFixture, "running", false, 5000)
      keys.forceActiveFocus()
      wait(100)
      keyClick(Qt.Key_R)
      tryCompare(widget, "hasError", false, 5000)
      check(widget.barText === "1.5K ($0.25)", "Refresh restores token metrics after installation")
      check(!banner.visible && !copyButton.visible, "Setup instructions disappear after recovery")
      console.log("SETUP CHECK PASS")
    }
  }
}
QML

# Quickshell's PanelWindow needs a native display backend. Use a separate config and home.
set +e
HOME="${CONFIG_DIR}/home" PATH=/usr/bin:/bin QT_QPA_PLATFORM=wayland \
  BASH_ENV="${CONFIG_DIR}/lookup.sh" \
  QT_QUICK_BACKEND=software SETUP_EVIDENCE_DIR="${EVIDENCE_DIR}" \
  timeout 20s qs --no-color -p "${CONFIG_DIR}" > "${EVIDENCE_DIR}/check.log" 2>&1
RESULT=$?
set -e
cat "${EVIDENCE_DIR}/check.log"
echo "Evidence: ${EVIDENCE_DIR}"
[[ ${RESULT} -eq 0 ]]
rg -q 'SETUP CHECK PASS' "${EVIDENCE_DIR}/check.log"
! rg -q 'SETUP CHECK FAIL|ERROR|ReferenceError|TypeError' "${EVIDENCE_DIR}/check.log"
