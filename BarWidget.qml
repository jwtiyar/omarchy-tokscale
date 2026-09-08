import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "jwty.tokscale"
  ipcTarget: "jwty.tokscale"
  manageIpc: false

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color subtleText: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
  readonly property color ultraSubtle: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  readonly property color accentColor: Color.accent
  readonly property color cyanColor: "#00d2ff"
  readonly property color emeraldColor: "#10b981"
  readonly property color amberColor: "#f59e0b"
  readonly property color violetColor: "#8b5cf6"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string statusCommand: {
    var resolved = Qt.resolvedUrl("status.sh").toString().replace(/^file:\/\//, "")
    return resolved !== "" ? resolved : ((Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/jwty.tokscale/status.sh")
  }
  readonly property string launchCommand: {
    var resolved = Qt.resolvedUrl("open-tokscale.sh").toString().replace(/^file:\/\//, "")
    return resolved !== "" ? resolved : ((Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/jwty.tokscale/open-tokscale.sh")
  }

  readonly property int refreshIntervalSec: Math.max(15, Number(setting("refreshIntervalSec", 60)) || 60)

  // Period Options: Day, Week, Month
  property string selectedPeriod: "today"
  readonly property var periods: [
    { id: "today", label: "Day" },
    { id: "week", label: "Week" },
    { id: "month", label: "Month" }
  ]

  function periodLabel(id) {
    if (id === "week") return "Week"
    if (id === "month") return "Month"
    return "Today"
  }

  readonly property string selectedPeriodLabel: periodLabel(selectedPeriod)

  function selectPeriod(p) {
    if (selectedPeriod === p) return
    selectedPeriod = p
    refresh()
  }

  property real totalTokens: 0
  property real totalCost: 0
  property real totalInput: 0
  property real totalOutput: 0
  property real totalCache: 0
  property int totalMessages: 0
  property string topClient: ""
  property string breakdownMode: "models" // "models" | "apps"
  property var topEntries: []
  property var topAppEntries: []
  property bool refreshing: false
  property bool hasError: false
  property string errorMessage: ""

  function formatAppName(slug) {
    var s = String(slug || "unknown").toLowerCase()
    if (s === "antigravity-cli") return "AGY CLI"
    if (s === "antigravity") return "AGY"
    if (s === "dsh") return "DeepSeek Harness"
    if (s === "omp") return "Oh My Pi (OMP)"
    if (s === "opencode") return "OpenCode"
    if (s === "openclaw") return "OpenClaw"
    if (s === "codex") return "Codex"
    if (s === "hermes") return "Hermes"
    if (s === "pi") return "Pi"
    if (s === "claude" || s === "claude-code") return "Claude Code"
    if (s === "cline") return "Cline"
    if (s === "gemini") return "Gemini CLI"
    if (s === "qwen") return "Qwen CLI"
    if (s === "kimi") return "Kimi CLI"
    if (s === "goose") return "Goose"
    if (s === "grok") return "Grok"
    if (s === "fx") return "Fx"
    if (s === "kilo" || s === "kilocode") return "Kilo Code"
    if (s === "freebuff") return "Freebuff"
    if (s === "zcode") return "ZCode"
    if (s === "cursor") return "Cursor"
    if (s.length > 0) return s.charAt(0).toUpperCase() + s.slice(1)
    return s
  }

  readonly property real cacheRatio: totalTokens > 0 ? (totalCache / totalTokens) : 0
  readonly property real inputRatio: totalTokens > 0 ? (totalInput / totalTokens) : 0
  readonly property real outputRatio: totalTokens > 0 ? (totalOutput / totalTokens) : 0

  function formatTokens(val) {
    var num = Number(val || 0)
    if (num >= 1000000000) return (num / 1000000000).toFixed(1) + "B"
    if (num >= 1000000) return (num / 1000000).toFixed(1) + "M"
    if (num >= 1000) return (num / 1000).toFixed(1) + "K"
    return num.toString()
  }

  function formatNumber(val) {
    var num = Math.round(Number(val || 0))
    if (num >= 1000000) return (num / 1000000).toFixed(1) + "M"
    if (num >= 1000) return (num / 1000).toFixed(1) + "k"
    return num.toString()
  }

  function formatCost(val) {
    var num = Number(val || 0)
    if (num > 0 && num < 0.01) return "<$0.01"
    return "$" + num.toFixed(2)
  }

  // Bar format: 144.0M ($27.86)
  readonly property string barText: {
    if (hasError && totalTokens === 0) return "tokscale error"
    if (refreshing && totalTokens === 0) return "…"
    return formatTokens(totalTokens) + " (" + formatCost(totalCost) + ")"
  }

  readonly property string tooltipText: {
    if (hasError) return "Tokscale error: " + (errorMessage || "error") + "\nRight-click to open TUI"
    var lines = [
      "Tokscale (" + selectedPeriodLabel + ")",
      "Total: " + formatTokens(totalTokens) + " · " + formatCost(totalCost),
      "Input: " + formatTokens(totalInput) + "  Output: " + formatTokens(totalOutput),
      "Cache: " + formatTokens(totalCache) + " (" + Math.round(cacheRatio * 100) + "%)",
      "Requests: " + totalMessages,
      "",
      "Left-click: Open compact overview & period switcher",
      "Right-click: Open interactive Tokscale TUI"
    ]
    return lines.join("\n")
  }

  function refresh() {
    if (statusProcess.running) return
    refreshing = true
    statusProcess.running = true
  }

  function launchApp() {
    if (root.bar) {
      root.bar.run(root.launchCommand)
    }
  }

  function parseStatus(raw) {
    try {
      var trimmed = String(raw || "").trim()
      if (!trimmed) {
        hasError = true
        errorMessage = "Empty output"
        return
      }
      var parsed = JSON.parse(trimmed)
      if (parsed && parsed.error) {
        hasError = true
        errorMessage = String(parsed.error)
        return
      }

      var inp = Number(parsed.totalInput || 0)
      var out = Number(parsed.totalOutput || 0)
      var cRead = Number(parsed.totalCacheRead || 0)
      var cWrite = Number(parsed.totalCacheWrite || 0)

      root.totalInput = inp
      root.totalOutput = out
      root.totalCache = cRead + cWrite
      root.totalTokens = inp + out + cRead + cWrite
      root.totalCost = Number(parsed.totalCost || 0)
      root.totalMessages = Number(parsed.totalMessages || 0)

      if (Array.isArray(parsed.entries) && parsed.entries.length > 0) {
        // 1. Models: aggregate by model name to show total per model across all clients
        var modelMap = {}
        for (var i = 0; i < parsed.entries.length; i++) {
          var item = parsed.entries[i]
          var mKey = item.model || "unknown"
          if (!modelMap[mKey]) {
            modelMap[mKey] = {
              model: mKey,
              cost: 0,
              input: 0,
              output: 0,
              cacheRead: 0,
              cacheWrite: 0,
              reasoning: 0,
              messageCount: 0
            }
          }
          modelMap[mKey].cost += Number(item.cost || 0)
          modelMap[mKey].input += Number(item.input || 0)
          modelMap[mKey].output += Number(item.output || 0)
          modelMap[mKey].cacheRead += Number(item.cacheRead || 0)
          modelMap[mKey].cacheWrite += Number(item.cacheWrite || 0)
          modelMap[mKey].reasoning += Number(item.reasoning || 0)
          modelMap[mKey].messageCount += Number(item.messageCount || 0)
        }

        var modelList = []
        for (var m in modelMap) {
          var mEntry = modelMap[m]
          var mTokens = mEntry.input + mEntry.output + mEntry.cacheRead + mEntry.cacheWrite
          // Include every model that has at least 1 token, cost > 0, or message calls > 0
          if (mTokens > 0 || mEntry.cost > 0 || mEntry.messageCount > 0) {
            modelList.push(mEntry)
          }
        }
        // Sort by cost descending; tie-break by total tokens descending
        modelList.sort(function(a, b) {
          var costDiff = Number(b.cost || 0) - Number(a.cost || 0)
          if (Math.abs(costDiff) > 0.00001) return costDiff
          var tokensA = a.input + a.output + a.cacheRead + a.cacheWrite
          var tokensB = b.input + b.output + b.cacheRead + b.cacheWrite
          return tokensB - tokensA
        })
        root.topEntries = modelList

        // 2. Apps: aggregated by client
        var appMap = {}
        for (var j = 0; j < parsed.entries.length; j++) {
          var appItem = parsed.entries[j]
          var appKey = appItem.client || "other"
          if (!appMap[appKey]) {
            appMap[appKey] = {
              name: appKey,
              cost: 0,
              input: 0,
              output: 0,
              cacheRead: 0,
              cacheWrite: 0,
              reasoning: 0,
              messageCount: 0
            }
          }
          appMap[appKey].cost += Number(appItem.cost || 0)
          appMap[appKey].input += Number(appItem.input || 0)
          appMap[appKey].output += Number(appItem.output || 0)
          appMap[appKey].cacheRead += Number(appItem.cacheRead || 0)
          appMap[appKey].cacheWrite += Number(appItem.cacheWrite || 0)
          appMap[appKey].reasoning += Number(appItem.reasoning || 0)
          appMap[appKey].messageCount += Number(appItem.messageCount || 0)
        }

        var appList = []
        for (var k in appMap) {
          var aEntry = appMap[k]
          var aTokens = aEntry.input + aEntry.output + aEntry.cacheRead + aEntry.cacheWrite
          // Include every app that has at least 1 token, cost > 0, or message calls > 0
          if (aTokens > 0 || aEntry.cost > 0 || aEntry.messageCount > 0) {
            appList.push(aEntry)
          }
        }
        // Sort by cost descending; tie-break by total tokens descending
        appList.sort(function(a, b) {
          var costDiff = Number(b.cost || 0) - Number(a.cost || 0)
          if (Math.abs(costDiff) > 0.00001) return costDiff
          var tokensA = a.input + a.output + a.cacheRead + a.cacheWrite
          var tokensB = b.input + b.output + b.cacheRead + b.cacheWrite
          return tokensB - tokensA
        })
        root.topAppEntries = appList
        root.topClient = appList.length > 0 ? root.formatAppName(appList[0].name) : ""
      } else {
        root.topEntries = []
        root.topAppEntries = []
        root.topClient = ""
      }

      root.hasError = false
      root.errorMessage = ""
    } catch (e) {
      console.warn("jwty.tokscale parse error", e)
      root.hasError = true
      root.errorMessage = "JSON parse error"
    }
  }

  Process {
    id: statusProcess
    command: [root.statusCommand, root.selectedPeriod]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
    onExited: function(code) {
      root.refreshing = false
      if (code !== 0 && root.errorMessage === "") {
        root.hasError = true
        root.errorMessage = "Exit code " + code
      }
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "jwty.tokscale"
    function refresh(): string { root.refresh(); return "ok" }
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
    function launch(): string { root.launchApp(); return "ok" }
    function setPeriod(p: string): string { root.selectPeriod(p); return "ok" }
    function setMode(m: string): string { root.breakdownMode = m; return "ok" }
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Bar button
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    fontSize: Style.font.bodySmall
    horizontalMargin: 8.5
    tooltipText: root.tooltipText
    active: root.opened
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        root.launchApp()
      } else {
        root.toggle()
      }
    }
  }

  // Popup panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onActivateRequested: root.refresh()
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === "1" || text === "d" || text === "D") root.selectPeriod("today")
        else if (text === "2" || text === "w" || text === "W") root.selectPeriod("week")
        else if (text === "3" || text === "m" || text === "M") root.selectPeriod("month")
        else if (text === "a" || text === "A") root.breakdownMode = "apps"
        else if (text === "x" || text === "X") root.breakdownMode = "models"
        else if (text === "o" || text === "O" || text === "t" || text === "T") {
          root.close()
          root.launchApp()
        }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelFlick.width
          spacing: Style.space(10)

        // Header
        Item {
          width: parent.width
          height: Style.space(26)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(7)

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(7)
              height: Style.space(7)
              radius: 4
              color: root.hasError ? root.amberColor : root.emeraldColor
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "TOKSCALE"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.refreshing ? "…" : ""
              color: root.subtleText
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Period selector
          BorderSurface {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Style.space(24)
            implicitWidth: periodRow.implicitWidth + Style.space(4)
            radius: 12
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            borderSpec: Border.none()

            Row {
              id: periodRow
              anchors.centerIn: parent
              spacing: Style.space(2)

              Repeater {
                model: root.periods

                Item {
                  required property var modelData
                  required property int index

                  width: Style.space(48)
                  height: Style.space(20)

                  readonly property bool isSelected: root.selectedPeriod === modelData.id
                  readonly property bool isHovered: segMouse.containsMouse

                  Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: isSelected
                      ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
                      : (isHovered ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07) : "transparent")

                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      color: isSelected ? root.foreground : root.subtleText
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }

                    MouseArea {
                      id: segMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.selectPeriod(modelData.id)
                    }
                  }
                }
              }
            }
          }
        }

        // Spend and token totals
        BorderSurface {
          width: parent.width
          implicitHeight: heroContent.implicitHeight + Style.space(16)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
          borderSpec: Border.controlSpec("normal", Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08), root.accentColor)

          Column {
            id: heroContent
            width: parent.width - Style.space(20)
            anchors.centerIn: parent
            spacing: Style.space(10)

            // Primary totals
            Item {
              width: parent.width
              implicitHeight: Math.max(spendCol.implicitHeight, tokenCol.implicitHeight)

              Column {
                id: spendCol
                anchors.left: parent.left
                spacing: Style.space(1)
                Text {
                  text: root.formatCost(root.totalCost)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                  font.bold: true
                }
                Text {
                  text: (root.selectedPeriodLabel + " Spend").toUpperCase()
                  color: root.subtleText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.8
                  font.bold: true
                }
              }

              Column {
                id: tokenCol
                anchors.right: parent.right
                spacing: Style.space(1)
                Text {
                  anchors.right: parent.right
                  text: root.formatTokens(root.totalTokens)
                  color: root.cyanColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                  font.bold: true
                }
                Text {
                  anchors.right: parent.right
                  text: "TOTAL TOKENS"
                  color: root.subtleText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.8
                  font.bold: true
                }
              }
            }

            // Cache, input, output ratio bar
            Item {
              width: parent.width
              height: Style.space(5)

              Rectangle {
                anchors.fill: parent
                radius: 3
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
              }

              Row {
                anchors.fill: parent

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1.0, root.cacheRatio))
                  height: parent.height
                  radius: 3
                  color: root.violetColor
                  visible: width > 0
                }

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1.0, root.inputRatio))
                  height: parent.height
                  radius: 3
                  color: root.cyanColor
                  visible: width > 0
                }

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1.0, root.outputRatio))
                  height: parent.height
                  radius: 3
                  color: root.emeraldColor
                  visible: width > 0
                }
              }
            }

            // Legend
            Row {
              width: parent.width
              spacing: Style.space(10)

              Row {
                spacing: Style.space(4)
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: root.violetColor }
                Text { text: "Cache " + root.formatTokens(root.totalCache); color: root.subtleText; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }

              Row {
                spacing: Style.space(4)
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: root.cyanColor }
                Text { text: "In " + root.formatTokens(root.totalInput); color: root.subtleText; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }

              Row {
                spacing: Style.space(4)
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: root.emeraldColor }
                Text { text: "Out " + root.formatTokens(root.totalOutput); color: root.subtleText; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }
          }
        }

        // Metrics strip
        BorderSurface {
          width: parent.width
          implicitHeight: Style.space(30)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025)
          borderSpec: Border.none()

          Item {
            anchors.centerIn: parent
            width: parent.width - Style.space(16)
            height: Style.space(20)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Cache Rate: " + (root.totalTokens > 0 ? (Math.round(root.cacheRatio * 100) + "%") : "0%")
              color: root.violetColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              text: root.totalMessages + " calls"
              color: root.subtleText
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.topClient ? ("Top: " + root.topClient) : ""
              color: root.subtleText
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              visible: root.topClient !== ""
            }
          }
        }

        // Breakdown list
        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: (root.breakdownMode === "models" ? root.topEntries.length : root.topAppEntries.length) > 0

          // Model and app toggle
          Item {
            width: parent.width
            implicitHeight: Style.space(22)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Rectangle {
                implicitWidth: modelsText.implicitWidth + Style.space(12)
                implicitHeight: Style.space(20)
                radius: 10
                color: root.breakdownMode === "models"
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                  : (modelsMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05) : "transparent")

                Text {
                  id: modelsText
                  anchors.centerIn: parent
                  text: "Models"
                  color: root.breakdownMode === "models" ? root.foreground : root.subtleText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: root.breakdownMode === "models"
                }

                MouseArea {
                  id: modelsMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.breakdownMode = "models"
                }
              }

              Rectangle {
                implicitWidth: appsText.implicitWidth + Style.space(12)
                implicitHeight: Style.space(20)
                radius: 10
                color: root.breakdownMode === "apps"
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                  : (appsMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05) : "transparent")

                Text {
                  id: appsText
                  anchors.centerIn: parent
                  text: "Apps"
                  color: root.breakdownMode === "apps" ? root.foreground : root.subtleText
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: root.breakdownMode === "apps"
                }

                MouseArea {
                  id: appsMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.breakdownMode = "apps"
                }
              }
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: (root.breakdownMode === "models" ? root.topEntries.length : root.topAppEntries.length) + (root.breakdownMode === "models" ? " active" : " apps")
              color: root.subtleText
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Repeater {
            model: root.breakdownMode === "models" ? root.topEntries : root.topAppEntries

            Item {
              required property var modelData
              required property int index

              width: parent.width
              implicitHeight: Style.space(28)

              readonly property bool isModelMode: root.breakdownMode === "models"
              readonly property string itemName: isModelMode ? (modelData.model || "unknown") : root.formatAppName(modelData.name)
              readonly property real itemTokens: Number(modelData.input || 0) + Number(modelData.output || 0) + Number(modelData.cacheRead || 0) + Number(modelData.cacheWrite || 0)
              readonly property real itemCost: Number(modelData.cost || 0)
              readonly property var activeList: isModelMode ? root.topEntries : root.topAppEntries
              readonly property real maxCost: {
                if (!activeList || activeList.length === 0) return 1.0
                var mc = 0
                for (var ci = 0; ci < activeList.length; ci++) {
                  var c = Number(activeList[ci].cost || 0)
                  if (c > mc) mc = c
                }
                return Math.max(0.01, mc)
              }
              readonly property real maxTokens: {
                if (!activeList || activeList.length === 0) return 1.0
                var mt = 0
                for (var ti = 0; ti < activeList.length; ti++) {
                  var t = Number(activeList[ti].input || 0) + Number(activeList[ti].output || 0) + Number(activeList[ti].cacheRead || 0) + Number(activeList[ti].cacheWrite || 0)
                  if (t > mt) mt = t
                }
                return Math.max(1.0, mt)
              }

              BorderSurface {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.02)
                borderSpec: Border.none()

                // Relative bar
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: {
                    if (itemCost > 0) return parent.width * Math.min(1.0, itemCost / maxCost)
                    if (itemTokens > 0) return parent.width * Math.min(1.0, itemTokens / maxTokens)
                    return 0
                  }
                  radius: Style.cornerRadius
                  color: isModelMode
                    ? Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.08)
                    : Qt.rgba(root.violetColor.r, root.violetColor.g, root.violetColor.b, 0.09)
                }

                Item {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)

                  Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: itemName
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - dataRow.implicitWidth - Style.space(10)
                  }

                  Row {
                    id: dataRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Text {
                      text: root.formatTokens(itemTokens)
                      color: root.subtleText
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    Text {
                      text: itemCost > 0 ? root.formatCost(itemCost) : (itemTokens > 0 ? "free" : (Number(modelData.messageCount || 0) > 0 ? (modelData.messageCount + " calls") : "$0.00"))
                      color: itemCost > 0 ? root.foreground : (itemTokens > 0 ? root.emeraldColor : root.subtleText)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }
                  }
                }
              }
            }
          }
        }

        // TUI launcher
        BorderSurface {
          width: parent.width
          implicitHeight: Style.space(28)
          radius: Style.cornerRadius
          color: launchArea.containsMouse
            ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
            : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          borderSpec: Border.none()

          Row {
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: "󰆍"
              color: root.cyanColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              text: "Open Tokscale TUI"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              text: "(or right-click bar)"
              color: root.subtleText
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            id: launchArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              root.launchApp()
            }
          }
        }
      }
    }
  }
}
}
