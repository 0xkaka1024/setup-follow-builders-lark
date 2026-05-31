#!/bin/zsh
set -euo pipefail

LABEL="com.local.follow-builders.lark-push"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

if [[ ! -f "$PLIST" ]]; then
  echo "Missing LaunchAgent: $PLIST" >&2
  exit 1
fi

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl print "$DOMAIN/$LABEL"
