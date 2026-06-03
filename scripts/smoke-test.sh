#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(mktemp -d /tmp/setup-follow-builders-lark-test.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT

HOME_DIR="$ROOT/home"
FOLLOW_BUILDERS_DIR="$ROOT/follow-builders"
FAKE_CODEX="$ROOT/codex"
FAKE_LARK="$ROOT/lark-cli"
LARK_LOG="$ROOT/lark.log"

mkdir -p "$FOLLOW_BUILDERS_DIR/scripts"

cat > "$FOLLOW_BUILDERS_DIR/scripts/prepare-digest.js" <<'EOF'
console.log(JSON.stringify({
  status: "ok",
  config: { language: "zh", frequency: "daily", delivery: { method: "lark" } },
  podcasts: [],
  x: [],
  blogs: [],
  stats: { podcastEpisodes: 0, xBuilders: 0, totalTweets: 0, blogPosts: 0 },
  prompts: { digest_intro: "Smoke test" }
}));
EOF

cat > "$FAKE_CODEX" <<'EOF'
#!/bin/zsh
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo "codex-cli smoke"
  exit 0
fi
OUTPUT=""
MODEL=""
PROMPT_TEXT=""
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then
    OUTPUT="$2"
    shift 2
    continue
  fi
  if [[ "$1" == "--model" ]]; then
    MODEL="$2"
    shift 2
    continue
  fi
  PROMPT_TEXT="$PROMPT_TEXT $1"
  shift
done
cat >/dev/null
if [[ -n "$MODEL" ]]; then
  echo "The '$MODEL' model is not supported when using Codex with this account." >&2
  exit 1
fi
if [[ "$PROMPT_TEXT" == *"Output exactly: OK"* ]]; then
  printf 'OK\n' > "$OUTPUT"
else
  printf 'AI Builders Digest | Smoke test\n' > "$OUTPUT"
fi
EOF

cat > "$FAKE_LARK" <<EOF
#!/bin/zsh
set -euo pipefail
if [[ "\${SMOKE_LARK_FAIL:-}" == "1" ]]; then
  echo "simulated lark failure" >&2
  exit 1
fi
printf '%s\n' "\$*" >> "$LARK_LOG"
printf '{"ok":true,"identity":"bot"}\n'
EOF

chmod 700 "$FAKE_CODEX" "$FAKE_LARK"

node "$SCRIPT_DIR/setup.mjs" \
  --home "$HOME_DIR" \
  --chat-id "oc_smoketest" \
  --follow-builders-dir "$FOLLOW_BUILDERS_DIR" \
  --codex-bin "$FAKE_CODEX" \
  --lark-bin "$FAKE_LARK" \
  --model "unsupported-model" \
  --node-bin "$(command -v node)" >/dev/null

RUNTIME="$HOME_DIR/.follow-builders/bin/push-lark-digest.sh"

HOME="$HOME_DIR" "$RUNTIME" --generate-only | grep -q "Smoke test"
grep -q "unsupported-model" "$HOME_DIR/.follow-builders/logs/codex-model-error.log"
HOME="$HOME_DIR" "$SCRIPT_DIR/preflight.sh" | grep -q "Preflight passed"
HOME="$HOME_DIR" "$RUNTIME" --force >/dev/null
HOME="$HOME_DIR" "$RUNTIME" | grep -q "Digest already sent"
grep -q -- "--chat-id oc_smoketest" "$LARK_LOG"
if SMOKE_LARK_FAIL=1 HOME="$HOME_DIR" "$RUNTIME" --force >/dev/null 2>&1; then
  echo "Expected Lark failure" >&2
  exit 1
fi
grep -q "stage: lark" "$HOME_DIR/.follow-builders/state/last-error.txt"
plutil -lint "$HOME_DIR/Library/LaunchAgents/com.local.follow-builders.lark-push.plist" >/dev/null

echo "Smoke test passed"
