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
OUTPUT=""
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then
    OUTPUT="$2"
    shift 2
    continue
  fi
  shift
done
cat >/dev/null
printf 'AI Builders Digest | Smoke test\n' > "$OUTPUT"
EOF

cat > "$FAKE_LARK" <<EOF
#!/bin/zsh
set -euo pipefail
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
  --node-bin "$(command -v node)" >/dev/null

RUNTIME="$HOME_DIR/.follow-builders/bin/push-lark-digest.sh"

HOME="$HOME_DIR" "$RUNTIME" --generate-only | grep -q "Smoke test"
HOME="$HOME_DIR" "$RUNTIME" --force >/dev/null
HOME="$HOME_DIR" "$RUNTIME" | grep -q "Digest already sent"
grep -q -- "--chat-id oc_smoketest" "$LARK_LOG"
plutil -lint "$HOME_DIR/Library/LaunchAgents/com.local.follow-builders.lark-push.plist" >/dev/null

echo "Smoke test passed"
