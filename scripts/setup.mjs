#!/usr/bin/env node

import { access, chmod, copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { constants } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const skillDir = dirname(scriptDir);
const args = parseArgs(process.argv.slice(2));
const home = args.home || homedir();
const userDir = join(home, ".follow-builders");
const launchAgentsDir = join(home, "Library", "LaunchAgents");
const label = "com.local.follow-builders.lark-push";
const plistPath = join(launchAgentsDir, `${label}.plist`);
const runtimeScript = join(userDir, "bin", "push-lark-digest.sh");
const promptPath = join(userDir, "prompts", "digest-intro.md");

if (process.platform !== "darwin" && !args.home) {
  fail("This setup script supports macOS only.");
}

const chatId = required(args, "chat-id");
if (!/^oc_[A-Za-z0-9]+$/.test(chatId)) fail("--chat-id must look like oc_xxx");

const deliveryTime = args.time || "08:00";
if (!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(deliveryTime)) fail("--time must use HH:MM");

const language = args.language || "zh";
if (!/^(zh|en|bilingual)$/.test(language)) fail("--language must be zh, en, or bilingual");

const timezone = args.timezone || "Asia/Shanghai";
if (!/^[A-Za-z_+-]+(?:\/[A-Za-z0-9_+.-]+)+$/.test(timezone)) {
  fail("--timezone must be an IANA timezone such as Asia/Shanghai");
}

const maxCharacters = Number(args["max-characters"] || "900");
if (!Number.isInteger(maxCharacters) || maxCharacters < 200 || maxCharacters > 5000) {
  fail("--max-characters must be an integer from 200 to 5000");
}

const model = args.model || "";
if (model && !/^[A-Za-z0-9._-]+$/.test(model)) fail("--model contains unsupported characters");

const followBuildersDir =
  args["follow-builders-dir"] || join(home, ".codex", "skills", "follow-builders");
await requireFile(join(followBuildersDir, "scripts", "prepare-digest.js"), "follow-builders");

const nodeBin = args["node-bin"] || which("node");
const localCodexBin = join(userDir, "codex-cli", "node_modules", ".bin", "codex");
const codexBin = args["codex-bin"] || ((await fileExists(localCodexBin)) ? localCodexBin : which("codex"));
const larkBin = args["lark-bin"] || which("lark-cli");

await mkdir(join(userDir, "bin"), { recursive: true });
await mkdir(join(userDir, "logs"), { recursive: true });
await mkdir(join(userDir, "prompts"), { recursive: true });
await mkdir(join(userDir, "state"), { recursive: true });
await mkdir(launchAgentsDir, { recursive: true });

const config = {
  platform: "other",
  language,
  timezone,
  frequency: "daily",
  deliveryTime,
  maxCharacters,
  model,
  delivery: { method: "lark", chatId },
  paths: { followBuildersDir, nodeBin, codexBin, larkBin },
  onboardingComplete: true,
};

await writeFile(join(userDir, "config.json"), `${JSON.stringify(config, null, 2)}\n`, "utf8");
await copyFile(join(scriptDir, "push-lark-digest.sh"), runtimeScript);
await chmod(runtimeScript, 0o700);

const promptTemplate = await readFile(join(skillDir, "assets", "digest-intro.md"), "utf8");
if (!(await fileExists(promptPath))) {
  await writeFile(
    promptPath,
    promptTemplate
      .replaceAll("{{MAX_CHARACTERS}}", String(maxCharacters))
      .replaceAll("{{LANGUAGE_INSTRUCTION}}", languageInstruction(language)),
    "utf8",
  );
}
await writeFile(plistPath, renderPlist({ label, runtimeScript, userDir, deliveryTime }), "utf8");

console.log(`Configured Follow Builders Lark digest.`);
console.log(`Config: ${join(userDir, "config.json")}`);
console.log(`LaunchAgent: ${plistPath}`);
console.log(`Preflight: ${join(scriptDir, "preflight.sh")}`);
console.log(`Preview: ${runtimeScript} --generate-only`);
console.log(`Enable after user confirmation: ${join(scriptDir, "enable.sh")}`);

function parseArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (!value.startsWith("--")) fail(`Unexpected argument: ${value}`);
    const key = value.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) fail(`Missing value for ${value}`);
    result[key] = next;
    index += 1;
  }
  return result;
}

function required(values, key) {
  if (!values[key]) fail(`Missing required --${key}`);
  return values[key];
}

function which(command) {
  const result = spawnSync("which", [command], { encoding: "utf8" });
  if (result.status !== 0) fail(`Missing required command: ${command}`);
  return result.stdout.trim();
}

async function requireFile(path, labelName) {
  try {
    await access(path, constants.R_OK);
  } catch {
    fail(`Missing ${labelName}: ${path}`);
  }
}

async function fileExists(path) {
  try {
    await access(path, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

function languageInstruction(value) {
  if (value === "zh") return "concise Chinese, except for unavoidable product names and URLs";
  if (value === "en") return "concise English";
  return "concise bilingual English and Chinese, interleaved paragraph by paragraph";
}

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function renderPlist({ label: serviceLabel, runtimeScript: script, userDir: directory, deliveryTime: time }) {
  const [hour, minute] = time.split(":").map(Number);
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${escapeXml(serviceLabel)}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>${escapeXml(script)}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>900</integer>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>${hour}</integer>
    <key>Minute</key>
    <integer>${minute}</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${escapeXml(join(directory, "logs", "push.log"))}</string>
  <key>StandardErrorPath</key>
  <string>${escapeXml(join(directory, "logs", "push-error.log"))}</string>
</dict>
</plist>
`;
}

function fail(message) {
  console.error(`Error: ${message}`);
  process.exit(1);
}
