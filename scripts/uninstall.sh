#!/bin/zsh
set -euo pipefail

LABEL="com.local.follow-builders.lark-push"
DOMAIN="gui/$(id -u)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "Disabled Follow Builders Lark automation."

if [[ "${1:-}" == "--purge" ]]; then
  rm -rf "$HOME/.follow-builders"
  echo "Deleted ~/.follow-builders configuration and logs."
fi
