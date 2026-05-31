#!/bin/zsh
set -euo pipefail

LABEL="com.local.follow-builders.lark-push"
DOMAIN="gui/$(id -u)"
CONFIG="$HOME/.follow-builders/config.json"

if [[ -f "$CONFIG" ]]; then
  cat "$CONFIG"
else
  echo "Missing config: $CONFIG"
fi

echo
if ! launchctl print "$DOMAIN/$LABEL"; then
  echo "LaunchAgent is not loaded."
fi
