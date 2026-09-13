#!/usr/bin/env bash
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$HOME/.npm-global/bin:$PATH:/usr/local/bin:/usr/bin"

if ! command -v tokscale >/dev/null 2>&1; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Tokscale" "Tokscale CLI is not installed. Install with: npm install -g tokscale" -u normal
  fi
  exit 1
fi

if command -v omarchy-launch-or-focus-tui >/dev/null 2>&1; then
  exec omarchy-launch-or-focus-tui tokscale tui
elif command -v omarchy-launch-tui >/dev/null 2>&1; then
  exec omarchy-launch-tui tokscale tui
else
  exec xdg-terminal-exec -e tokscale tui
fi
