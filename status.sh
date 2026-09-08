#!/usr/bin/env bash
set -eo pipefail

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$HOME/.npm-global/bin:$PATH:/usr/local/bin:/usr/bin"

PERIOD="${1:-today}"
case "$PERIOD" in
  week) FLAG="--week" ;;
  month) FLAG="--month" ;;
  all) FLAG="" ;;
  *) FLAG="--today" ;;
esac

if command -v tokscale >/dev/null 2>&1; then
  tokscale antigravity sync >/dev/null 2>&1 || true
  if [ -n "$FLAG" ]; then
    exec tokscale "$FLAG" --json --no-spinner
  else
    exec tokscale --json --no-spinner
  fi
else
  echo '{"error":"tokscale not found in PATH"}'
  exit 1
fi
