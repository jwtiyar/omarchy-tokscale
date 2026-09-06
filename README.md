# Omarchy Tokscale Plugin (`jwty.tokscale`)

A modern, compact, anti-slop status bar plugin and dropdown widget for [Omarchy](https://omarchy.org), powered by [Tokscale](https://github.com/tokscale/tokscale).

Displays your daily/weekly/monthly AI token consumption and spend directly on the status bar, with an interactive popup dashboard and 1-click launcher for the interactive Tokscale TUI.

---

## ✨ Features

- **Compact Status Bar Pill**: Clean, readable format showing live token count and spend:
  ```text
  144.0M ($27.86)
  ```
- **Interactive Popup Dashboard (Left-Click)**:
  - **Timeframe Switcher**: Instant toggle between **Today** (`daily`), **Week** (`weekly`), and **Month** (`monthly`).
  - **Hero Stats**: High-visibility cards for spend, total tokens, and breakdown.
  - **Cache & Efficiency Stats**: Displays cache rate percentage, total API calls, and top consuming client.
  - **Unified Breakdown (Models vs. Apps)**:
    - **Models**: Top model rankings with proportional spend bars, token counts, and cost.
    - **Apps**: Aggregates all activity by client application (e.g. Codex, Hermes, Antigravity CLI, Pi, Claude Code).
- **Direct TUI Launcher (Right-Click)**: Right-clicking the status bar pill immediately focuses or launches `tokscale tui` in your terminal.
- **IPC Support**: Fully scriptable and controllable via Quickshell IPC commands.

---

## 📦 Requirements

- **Omarchy Shell** (`quickshell`)
- **Tokscale CLI** (`>= 4.15.0`) installed on your PATH:
  ```bash
  npm install -g tokscale
  # or
  pnpm add -g tokscale
  ```

---

## 🚀 Installation

### Automatic

Clone the repository and run the install script:

```bash
git clone https://github.com/jwtiyar/omarchy-tokscale.git
cd omarchy-tokscale
./install.sh
```

### Manual

Copy the plugin directory into your Omarchy plugins folder:

```bash
mkdir -p ~/.config/omarchy/plugins/jwty.tokscale
cp manifest.json BarWidget.qml status.sh open-tokscale.sh ~/.config/omarchy/plugins/jwty.tokscale/
chmod +x ~/.config/omarchy/plugins/jwty.tokscale/*.sh
```

Add the widget to your bar layout in `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "right": [
        "jwty.tokscale"
      ]
    }
  }
}
```

Then reload Omarchy:

```bash
omarchy restart shell
```

---

## ⌨️ Controls & Shortcuts

| Action | Result |
| :--- | :--- |
| **Left Click** on bar pill | Toggles the dropdown widget |
| **Right Click** on bar pill | Directly launches / focuses `tokscale tui` |
| **Escape** (inside widget) | Closes the dropdown |
| **Enter / Space** (inside widget) | Manually refreshes token data |

---

## 📡 IPC Control

Control the widget programmatically via Quickshell IPC:

```bash
# Refresh token usage data
qs -p ~/omarchy/shell ipc call jwty.tokscale refresh

# Toggle popup open / close
qs -p ~/omarchy/shell ipc call jwty.tokscale toggle

# Change period ('today', 'week', 'month')
qs -p ~/omarchy/shell ipc call jwty.tokscale setPeriod week

# Switch breakdown view ('models', 'apps')
qs -p ~/omarchy/shell ipc call jwty.tokscale setMode apps

# Launch Tokscale TUI
qs -p ~/omarchy/shell ipc call jwty.tokscale launch
```

---

## 📄 License

MIT © [jwty](https://github.com/jwtiyar)
