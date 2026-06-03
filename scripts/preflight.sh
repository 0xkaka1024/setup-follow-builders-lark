#!/bin/zsh
set -euo pipefail

export PATH="$HOME/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

USER_DIR="${FOLLOW_BUILDERS_USER_DIR:-$HOME/.follow-builders}"
CONFIG_PATH="$USER_DIR/config.json"
WORK_DIR="$(mktemp -d /tmp/follow-builders-lark-preflight.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  echo "Preflight failed: $1" >&2
  exit 1
}

ok() {
  echo "ok: $1"
}

if [[ ! -f "$CONFIG_PATH" ]]; then
  fail "missing config at $CONFIG_PATH. Run scripts/setup.mjs first."
fi

NODE_BIN="${NODE_BIN:-$(command -v node || true)}"
if [[ -z "$NODE_BIN" || ! -x "$NODE_BIN" ]]; then
  fail "node is not available on PATH."
fi
ok "node"

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

[[ -f "$FOLLOW_BUILDERS_DIR/scripts/prepare-digest.js" ]] || fail "missing follow-builders prepare-digest.js at $FOLLOW_BUILDERS_DIR/scripts."
[[ -x "$CODEX_BIN" ]] || fail "codex is not executable at $CODEX_BIN."
[[ -x "$LARK_BIN" ]] || fail "lark-cli is not executable at $LARK_BIN."
ok "required files and commands"

"$NODE_BIN" --version >/dev/null || fail "node exists but cannot run."
"$CODEX_BIN" --version >/dev/null || fail "codex exists but cannot run."
"$LARK_BIN" auth status >/dev/null || fail "lark-cli auth status failed. Re-run Lark authorization."
ok "tool versions and Lark auth"

cd "$FOLLOW_BUILDERS_DIR/scripts"
"$NODE_BIN" prepare-digest.js > "$WORK_DIR/input.json" || fail "follow-builders feed generation failed."
"$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$WORK_DIR/input.json" || fail "follow-builders returned invalid JSON."
ok "follow-builders feed"

CODEX_MODEL_ARGS=()
if [[ -n "$MODEL" ]]; then
  CODEX_MODEL_ARGS=(--model "$MODEL")
fi

run_codex_check() {
  local log_path="$1"
  shift
  "$CODEX_BIN" exec \
    "$@" \
    --config 'model_reasoning_effort="low"' \
    --sandbox read-only \
    --skip-git-repo-check \
    --cd "$USER_DIR" \
    --output-last-message "$WORK_DIR/codex-output.txt" \
    'Output exactly: OK' > "$log_path" 2>&1
}

CODEX_STATUS=0
run_codex_check "$WORK_DIR/codex.log" "${CODEX_MODEL_ARGS[@]}" || CODEX_STATUS=$?

if [[ "$CODEX_STATUS" != "0" && -n "$MODEL" ]] && grep -Eqi "model .*not supported|requires a newer version of Codex" "$WORK_DIR/codex.log"; then
  echo "warn: configured model '$MODEL' failed; retrying Codex default model"
  : > "$WORK_DIR/codex-output.txt"
  CODEX_STATUS=0
  run_codex_check "$WORK_DIR/codex.log" || CODEX_STATUS=$?
fi

if [[ "$CODEX_STATUS" != "0" || "$(tr -d '[:space:]' < "$WORK_DIR/codex-output.txt" 2>/dev/null)" != "OK" ]]; then
  fail "Codex CLI could not generate a minimal response. Check Codex login, CLI version, and model configuration."
fi
ok "Codex minimal generation"

echo "Preflight passed."
