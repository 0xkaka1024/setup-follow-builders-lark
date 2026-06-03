#!/bin/zsh
set -euo pipefail

export PATH="$HOME/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

USER_DIR="${FOLLOW_BUILDERS_USER_DIR:-$HOME/.follow-builders}"
CONFIG_PATH="$USER_DIR/config.json"
STATE_DIR="$USER_DIR/state"
LAST_SUCCESS_FILE="$STATE_DIR/last-successful-push-date"
LOCK_DIR="$STATE_DIR/push.lock"
MODE="${1:-}"
LOCK_HELD=0

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Missing config: $CONFIG_PATH" >&2
  exit 1
fi

NODE_BIN="${NODE_BIN:-$(command -v node)}"

config_value() {
  "$NODE_BIN" -e '
    const fs = require("fs");
    const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const value = process.argv[2].split(".").reduce((current, key) => current?.[key], data);
    if (value === undefined || value === null || value === "") process.exit(2);
    process.stdout.write(String(value));
  ' "$CONFIG_PATH" "$1"
}

FOLLOW_BUILDERS_DIR="$(config_value paths.followBuildersDir)"
CODEX_BIN="$(config_value paths.codexBin)"
LARK_BIN="$(config_value paths.larkBin)"
MODEL="$(config_value model 2>/dev/null || true)"
MAX_CHARACTERS="$(config_value maxCharacters)"
CHAT_ID="$(config_value delivery.chatId)"
DELIVERY_TIME="$(config_value deliveryTime | tr -d ':')"
LANGUAGE="$(config_value language)"
TIMEZONE="$(config_value timezone)"
TODAY="$(TZ="$TIMEZONE" date +%F)"
CURRENT_TIME="$(TZ="$TIMEZONE" date +%H%M)"

case "$LANGUAGE" in
  zh) LANGUAGE_INSTRUCTION="concise Chinese only, except for unavoidable product names and URLs" ;;
  en) LANGUAGE_INSTRUCTION="concise English only" ;;
  bilingual) LANGUAGE_INSTRUCTION="concise bilingual English and Chinese, interleaved paragraph by paragraph" ;;
  *) echo "Unsupported language: $LANGUAGE" >&2; exit 1 ;;
esac

mkdir -p "$STATE_DIR" "$USER_DIR/logs"

if [[ "$MODE" != "--generate-only" ]]; then
  if [[ "$MODE" != "--force" && "$CURRENT_TIME" < "$DELIVERY_TIME" ]]; then
    echo "Before the scheduled send time; skipping"
    exit 0
  fi

  if [[ "$MODE" != "--force" && -f "$LAST_SUCCESS_FILE" && "$(cat "$LAST_SUCCESS_FILE")" == "$TODAY" ]]; then
    echo "Digest already sent for $TODAY; skipping"
    exit 0
  fi

  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    if [[ -n "$(find "$LOCK_DIR" -type d -mmin +30 -print -quit 2>/dev/null)" ]]; then
      rmdir "$LOCK_DIR"
      mkdir "$LOCK_DIR"
    else
      echo "Digest push is already running; skipping"
      exit 0
    fi
  fi
  LOCK_HELD=1
fi

WORK_DIR="$(mktemp -d /tmp/follow-builders-lark.XXXXXX)"
cleanup() {
  rm -rf "$WORK_DIR"
  if [[ "$LOCK_HELD" == "1" ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

cd "$FOLLOW_BUILDERS_DIR/scripts"
"$NODE_BIN" prepare-digest.js > "$WORK_DIR/input.json"

cat > "$WORK_DIR/request.txt" <<EOF
Generate the final AI Builders Digest message from the JSON appended below.

Requirements:
- Follow the prompts contained in the JSON.
- Output $LANGUAGE_INSTRUCTION.
- Prioritize high-signal builder updates. Include at most 4 X/Twitter updates, at most 1 blog post, and at most 1 podcast episode.
- Keep the whole message under about $MAX_CHARACTERS Chinese characters, excluding URLs.
- For a podcast, include one takeaway sentence and at most 3 short bullet points.
- Include the source URL for every item.
- Do not browse the web, call APIs, run shell commands, or explain your process.
- Output only the final digest text.

Input JSON:
EOF

cat "$WORK_DIR/input.json" >> "$WORK_DIR/request.txt"

CODEX_MODEL_ARGS=()
if [[ -n "$MODEL" ]]; then
  CODEX_MODEL_ARGS=(--model "$MODEL")
fi

"$CODEX_BIN" exec \
  "${CODEX_MODEL_ARGS[@]}" \
  --config 'model_reasoning_effort="low"' \
  --sandbox read-only \
  --skip-git-repo-check \
  --cd "$USER_DIR" \
  --output-last-message "$WORK_DIR/digest.txt" \
  - < "$WORK_DIR/request.txt" > "$USER_DIR/logs/codex.log" 2>&1

if [[ ! -s "$WORK_DIR/digest.txt" ]]; then
  echo "Digest generation returned no content" >&2
  exit 1
fi

DIGEST="$(cat "$WORK_DIR/digest.txt")"

if [[ "$MODE" == "--generate-only" ]]; then
  print -r -- "$DIGEST"
  exit 0
fi

"$LARK_BIN" im +messages-send \
  --chat-id "$CHAT_ID" \
  --text "$DIGEST" \
  --as bot

printf '%s\n' "$TODAY" > "$LAST_SUCCESS_FILE.tmp"
mv "$LAST_SUCCESS_FILE.tmp" "$LAST_SUCCESS_FILE"
