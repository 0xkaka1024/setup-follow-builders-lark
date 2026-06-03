#!/bin/zsh
set -euo pipefail

LABEL="com.local.follow-builders.lark-push"
DOMAIN="gui/$(id -u)"
CONFIG="$HOME/.follow-builders/config.json"
LAST_ERROR="$HOME/.follow-builders/state/last-error.txt"

if [[ -f "$CONFIG" ]]; then
  cat "$CONFIG"
else
  echo "Missing config: $CONFIG"
fi

echo
if [[ -f "$LAST_ERROR" ]]; then
  echo "Last recorded error:"
  cat "$LAST_ERROR"
else
  echo "Last recorded error: none"
fi

echo
if ! launchctl print "$DOMAIN/$LABEL"; then
  echo "LaunchAgent is not loaded."
fi
