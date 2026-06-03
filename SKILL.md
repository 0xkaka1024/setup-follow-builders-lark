---
name: setup-follow-builders-lark
description: Set up and manage a macOS automation that sends a concise daily Follow Builders AI digest to a Lark group using follow-builders, Codex CLI, lark-cli, and launchd. Use when the user wants AI Builders summaries in Lark, wants a daily scheduled digest, needs sleep/wake or reboot catch-up delivery, wants to test the Lark digest, or wants to inspect, change, or remove the local macOS automation.
---

# Setup Follow Builders Lark

Set up a local macOS pipeline:

```text
launchd -> follow-builders public feed -> codex exec -> lark-cli bot message
```

Keep the first version focused: use the centrally maintained Follow Builders sources. Do not expose RSS, JSON feed, or arbitrary shell customization.

## Safety Rules

- Confirm the target Lark group, bot identity, and exact test message before sending any visible message.
- Ask for confirmation before enabling, disabling, or uninstalling the scheduled task.
- Never print app secrets, tokens, or local credential files.
- Do not weaken macOS Keychain protection. The verified pipeline works through the logged-in user's LaunchAgent.
- Explain that this is a local automation: it works with Codex App closed, but requires the Mac to be powered on or later booted and the macOS user to log in. It does not run while the computer is powered off.

## Prerequisites

Require macOS, Node.js, Codex CLI, `follow-builders`, and `lark-cli`.

Check:

```bash
uname -s
which node
which codex
which lark-cli
test -f ~/.codex/skills/follow-builders/scripts/prepare-digest.js
```

If `follow-builders` is missing, use the system `skill-installer` workflow to install `https://github.com/zarazhangrui/follow-builders`, then run:

```bash
cd ~/.codex/skills/follow-builders/scripts && npm install
```

If `lark-cli` is missing, install the official CLI:

```bash
npm install -g @larksuite/cli@latest
```

If Lark is not configured, run `lark-cli config init --new`, relay the official setup URL, and wait for the user to finish. Verify:

```bash
lark-cli auth status
```

## Choose the Lark Group

Prefer an existing group if the user names one. Otherwise create a private `AI Builders Digest` group.

Use the installed `lark-im` skill when available. Read its shared authentication rules first. For a new group:

1. Obtain the user's `open_id` with a minimal user authorization:

   ```bash
   lark-cli auth login --scope "contact:user.base:readonly" --no-wait --json
   ```

2. Relay the official URL and required QR code. After the user authorizes, finish with:

   ```bash
   lark-cli auth login --device-code "<device_code>"
   ```

3. Read the configured app ID from `lark-cli auth status`, then create the private group:

   ```bash
   lark-cli im +chat-create \
     --name "AI Builders Digest" \
     --description "每日 AI Builders 中文简短摘要" \
     --users "<user_open_id>" \
     --bots "<app_id>" \
     --set-bot-manager \
     --as bot \
     --format json
   ```

## Install the Local Files

Run the bundled setup script. It writes configuration, the runtime push script, the concise Chinese prompt, and a LaunchAgent plist. It does not enable the task yet.

```bash
node scripts/setup.mjs \
  --chat-id "oc_xxx" \
  --time "08:00" \
  --timezone "Asia/Shanghai" \
  --language "zh" \
  --max-characters 900
```

By default the automation uses the model from the user's Codex CLI configuration. Override only if the local Codex CLI and the account both support the requested model:

```bash
node scripts/setup.mjs --chat-id "oc_xxx" --model "gpt-5.5"
```

## Preview, Confirm, Send, Enable

Generate a preview without sending:

```bash
~/.follow-builders/bin/push-lark-digest.sh --generate-only
```

Show the preview. Ask the user to confirm:

1. Send the preview now to the named Lark group as the bot.
2. Allow future automatic messages of the same type.

After confirmation:

```bash
~/.follow-builders/bin/push-lark-digest.sh --force
scripts/enable.sh
```

`--force` sends a test digest and records today's success. Loading the task then runs its login check but safely skips the duplicate.

## Delivery Behavior

The LaunchAgent:

- Runs daily at the configured time.
- Runs when the user logs in.
- Checks every 15 minutes for missed delivery or transient network failure.
- Sends at most once per configured timezone calendar day unless explicitly forced.
- Skips login checks before the scheduled delivery time.
- Clears stale locks after 30 minutes.

Sleeping or powered-off Macs cannot send at the scheduled instant. After wake or reboot plus login, the next check sends the missed digest.

`launchd` schedules against the Mac's system timezone. Keep the Mac system timezone aligned with `--timezone` when exact wall-clock delivery matters.

## Manage the Automation

Inspect:

```bash
scripts/status.sh
tail -n 80 ~/.follow-builders/logs/push.log
tail -n 80 ~/.follow-builders/logs/push-error.log
```

Change schedule or digest length by rerunning `scripts/setup.mjs`, then reload:

```bash
scripts/enable.sh
```

Disable without deleting configuration:

```bash
scripts/uninstall.sh
```

Delete configuration only after explicit confirmation:

```bash
scripts/uninstall.sh --purge
```

## Source Policy

The Follow Builders source list is centrally maintained by its upstream project. If the user asks to add or remove builders, podcasts, or blogs, explain that this version intentionally keeps the curated default sources. Suggest opening an upstream issue at `https://github.com/zarazhangrui/follow-builders` or iterating this skill later.
