# Tokscale for Omarchy

Status bar widget for [Omarchy](https://omarchy.org) that tracks AI token usage and costs via [Tokscale](https://github.com/tokscale/tokscale).

Shows daily, weekly, monthly, or all-time token count and spend on the bar, with a popup dashboard and terminal TUI shortcut.

## Features

- **Status bar pill:** Shows current token count and cost (e.g. `144.0M ($27.86)`).
- **Dashboard popup:** Left-click to inspect tokens, spend, cache rates, request counts, and breakdowns grouped by model or client application.
- **Time ranges:** Filter by today, this week, this month, or all time.
- **TUI shortcut:** Right-click to launch or focus `tokscale tui` in the terminal.
- **IPC support:** Control data refreshes and popup state via Quickshell IPC.

## Requirements

- Omarchy shell (`quickshell`)
- `tokscale` CLI installed on PATH:
  ```bash
  npm install -g tokscale
  # or
  pnpm add -g tokscale
  ```

## Installation

### Automatic

```bash
git clone https://github.com/jwtiyar/omarchy-tokscale.git
cd omarchy-tokscale
./install.sh
```

### Manual

Copy the files into your Omarchy plugin directory:

```bash
mkdir -p ~/.config/omarchy/plugins/jwty.tokscale
cp manifest.json BarWidget.qml status.sh open-tokscale.sh ~/.config/omarchy/plugins/jwty.tokscale/
chmod +x ~/.config/omarchy/plugins/jwty.tokscale/*.sh
```

Add the plugin to `~/.config/omarchy/shell.json`:

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

Reload the shell:

```bash
omarchy restart shell
```

## Controls

| Action | Result |
| :--- | :--- |
| Left click bar pill | Toggle dashboard popup |
| Right click bar pill | Open or focus `tokscale tui` |
| Escape | Close dashboard popup |
| Enter / Space | Refresh data |

## IPC commands

```bash
# Refresh data
qs -p ~/omarchy/shell ipc call jwty.tokscale refresh

# Toggle popup
qs -p ~/omarchy/shell ipc call jwty.tokscale toggle

# Set period ('today', 'week', 'month', 'all')
qs -p ~/omarchy/shell ipc call jwty.tokscale setPeriod week

# Set breakdown view ('models', 'apps')
qs -p ~/omarchy/shell ipc call jwty.tokscale setMode apps

# Open TUI
qs -p ~/omarchy/shell ipc call jwty.tokscale launch
```

## Credits

- [Tokscale](https://github.com/tokscale/tokscale) for the CLI, data collection, and TUI.
- [Codeburn](https://github.com/getagentseal/codeburn) for design ideas and token tracking patterns.

## License

MIT © [jwty](https://github.com/jwtiyar)

