# Follow Builders Daily Feishu Digest

[简体中文](README.md) | [English](README_EN.md)

![Platform](https://img.shields.io/badge/platform-macOS%20only-lightgrey)
![Delivery](https://img.shields.io/badge/delivery-Feishu-blue)
![Source](https://img.shields.io/badge/source-follow--builders-orange)
![License](https://img.shields.io/badge/license-MIT-green)

A Codex skill for macOS users that automatically summarizes important AI industry updates and sends a concise daily digest to a Feishu group.

It is designed for people who want to follow AI industry developments in Feishu without maintaining their own information sources.

## What You Will Receive

One concise Feishu message each day:

- Up to 4 high-value AI builder updates
- Up to 1 official blog post
- Up to 1 podcast summary
- Original links for every item
- Chinese by default, limited to approximately 900 Chinese characters

Example:

```text
AI Builders Digest | 2026-05-30

1. Boris Cherny: The teams that gain the most from AI do not simply speed up
old workflows. They let agents own outcomes end-to-end and remove unnecessary
handoffs.
https://x.com/...

Podcast
Companies need "agents that supervise agents": use small models to identify
high-risk actions and reserve expensive intelligence for critical moments.
https://www.youtube.com/...
```

## Quick Start

Enter this in Codex:

```text
Install and use this skill:
https://github.com/0xkaka1024/setup-follow-builders-lark
```

Restart Codex after installation, then enter:

```text
Use setup-follow-builders-lark to set up a daily Feishu AI digest at 8:00 AM.
```

Codex will guide you through the setup. You do not need to edit configuration files manually.

Advanced users can also install it manually:

```bash
git clone https://github.com/0xkaka1024/setup-follow-builders-lark.git \
  ~/.codex/skills/setup-follow-builders-lark
```

## First-Time Setup

Initial setup usually takes 3-5 minutes:

```text
Install dependencies
→ Configure a Feishu app bot
→ Create or select a digest group
→ Preview the digest
→ Confirm a test message
→ Enable the scheduled task
```

During setup, you will see the required permission confirmations and the official Feishu authorization page. Before enabling the scheduled task, Codex will show a digest preview and ask for confirmation.

## How It Works

```text
macOS launchd starts the scheduled task
→ follow-builders fetches public feeds
→ codex exec generates a concise digest
→ the lark-cli bot sends it to a Feishu group
```

This project is not a fork of [follow-builders](https://github.com/zarazhangrui/follow-builders), and it does not copy its data-fetching logic. It reuses the locally installed follow-builders scripts and the public sources maintained upstream.

Digest generation and Feishu delivery both run on your Mac:

- No X/Twitter or YouTube API key is required
- Your Feishu credentials are not uploaded
- The default follow-builders sources are not modified
- Unrelated Feishu capabilities such as Docs, Sheets, and Calendar are not enabled

## Requirements

The current version supports macOS only.

First-time setup requires:

- Node.js
- Codex CLI with an active login
- A Feishu account
- A network connection

The skill checks for and guides the installation of:

- [follow-builders](https://github.com/zarazhangrui/follow-builders)
- [larksuite/cli](https://github.com/larksuite/cli)

## Scheduled Delivery Behavior

The default delivery time is 8:00 AM every day. You can adjust the time, language, and digest length during setup.

| State | Behavior |
|---|---|
| Codex App is closed | Sends normally |
| Screen is off | Sends normally |
| Mac is asleep | Sends after wake-up |
| Mac is shut down | Sends after startup and macOS login |
| Network is unavailable at startup | Retries after reconnecting |
| macOS user is not logged in | Does not send yet |

To reduce missed and duplicate messages, the task also:

- Checks every 15 minutes for a pending delivery
- Automatically sends at most once per day
- Cleans up stale task locks after 30 minutes

This is local automation, not a cloud service. It cannot send at the scheduled time while your computer is powered off.

## Common Operations

Tell Codex directly:

```text
Change the digest delivery time to 9:00 AM every day.
Make the digest shorter.
Preview today's digest.
Send one test message.
Show my current settings.
Disable automatic delivery.
```

Advanced users can inspect the status and logs:

```bash
~/.codex/skills/setup-follow-builders-lark/scripts/status.sh
tail -n 80 ~/.follow-builders/logs/push.log
tail -n 80 ~/.follow-builders/logs/push-error.log
```

## Troubleshooting

| Problem | Recommendation |
|---|---|
| No digest received | Run `status.sh` and confirm that the task is loaded |
| No Feishu message | Check `push-error.log` and confirm that the bot is still in the digest group |
| Digest generation fails | Confirm that Codex CLI is still logged in |
| No catch-up delivery after sleep or shutdown | Log in to macOS, reconnect to the network, and wait up to 15 minutes |
| Need an immediate test | Ask Codex to preview the digest, then confirm one test send |

## Uninstall

Disable automatic delivery while keeping your configuration and logs:

```bash
~/.codex/skills/setup-follow-builders-lark/scripts/uninstall.sh
```

Remove the local configuration and logs as well:

```bash
~/.codex/skills/setup-follow-builders-lark/scripts/uninstall.sh --purge
```

Codex will ask for confirmation before uninstalling.

## Privacy and Permissions

- Feishu credentials remain on your Mac
- Feishu tokens are not written to the repository
- macOS Keychain protections are not weakened
- Codex asks for confirmation before sending visible Feishu messages
- Codex asks for confirmation before enabling, disabling, or uninstalling the scheduled task
- Only Feishu instant messaging capabilities are used to send messages and create the digest group

## Sources and Limitations

The default information sources are centrally maintained and updated by [follow-builders](https://github.com/zarazhangrui/follow-builders).

The current version intentionally stays simple and does not support:

- Adding or removing builders, podcasts, or blogs
- Custom RSS or JSON feeds
- Arbitrary webpage scraping
- Arbitrary shell commands
- Windows or Linux
- Cloud-based scheduling

## License

[MIT](LICENSE)

## Credits

- Feed collection and default sources: [zarazhangrui/follow-builders](https://github.com/zarazhangrui/follow-builders)
- Feishu message delivery: [larksuite/cli](https://github.com/larksuite/cli)
