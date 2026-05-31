# Follow Builders 飞书每日摘要

![Platform](https://img.shields.io/badge/platform-macOS-only-lightgrey)
![Delivery](https://img.shields.io/badge/delivery-Feishu-blue)
![Source](https://img.shields.io/badge/source-follow--builders-orange)
![License](https://img.shields.io/badge/license-MIT-green)

一个面向 macOS 用户的 Codex skill：每天自动整理 AI 行业重要动态，并将简短摘要发送到飞书群。

适合希望在飞书中快速了解 AI 行业动态，但不想自行维护信息源的用户。

## 你会收到什么

每天一条适合快速阅读的飞书消息：

- 最多 4 条高价值 AI builders 动态
- 最多 1 篇官方博客文章
- 最多 1 期播客摘要
- 每条内容附带原始链接
- 默认使用中文，控制在约 900 字以内

示例：

```text
AI Builders Digest | 2026-05-30

1. Boris Cherny：真正从 AI 获得最大收益的团队，不是简单加速旧流程，
而是让 agent 端到端负责结果，并删除不必要的交接步骤。
https://x.com/...

Podcast
企业需要“看护 agent 的 agent”，用小模型筛选高风险动作，
把昂贵的智能留给关键时刻。
https://www.youtube.com/...
```

## 快速开始

在 Codex 中输入：

```text
帮我安装并使用这个 skill：
https://github.com/0xkaka1024/setup-follow-builders-lark
```

安装完成后重启 Codex，再输入：

```text
使用 setup-follow-builders-lark 帮我设置每天早上 8 点的飞书 AI 摘要
```

Codex 会逐步引导你完成设置，不需要手动编辑配置文件。

高级用户也可以手动安装：

```bash
git clone https://github.com/0xkaka1024/setup-follow-builders-lark.git \
  ~/.codex/skills/setup-follow-builders-lark
```

## 首次设置

首次设置通常需要 3-5 分钟：

```text
安装依赖
→ 配置飞书应用机器人
→ 创建或选择摘要群
→ 预览摘要
→ 确认测试发送
→ 启用定时任务
```

安装期间会出现必要的权限确认和飞书官方授权页面。启用定时任务前，Codex 会先展示摘要预览并请求确认。

## 工作原理

```text
macOS launchd 定时启动
→ follow-builders 拉取公开 feed
→ codex exec 生成短摘要
→ lark-cli 机器人发送到飞书群
```

本项目不是 [follow-builders](https://github.com/zarazhangrui/follow-builders) 的 fork，也不复制其数据抓取逻辑。它复用 follow-builders 在用户本地安装的脚本和上游维护的公开信息源。

摘要生成和飞书推送都在你的 Mac 上执行：

- 不需要配置 X/Twitter 或 YouTube API Key
- 不会上传你的飞书密钥
- 不会修改 follow-builders 的默认信息源
- 不会启用飞书文档、表格、日历等无关能力

## 运行条件

当前版本仅支持 macOS。

首次设置需要：

- Node.js
- Codex CLI，并已登录
- 飞书账号
- 网络连接

skill 会检查并引导安装：

- [follow-builders](https://github.com/zarazhangrui/follow-builders)
- [larksuite/cli](https://github.com/larksuite/cli)

## 自动推送行为

默认每天上午 8 点推送。时间、语言和摘要长度可以在设置时调整。

| 状态 | 行为 |
|---|---|
| 关闭 Codex App | 正常发送 |
| 仅关闭屏幕 | 正常发送 |
| Mac 睡眠 | 唤醒后补发 |
| Mac 关机 | 开机并登录 macOS 后补发 |
| 开机时临时断网 | 联网后重试 |
| macOS 用户未登录 | 暂不发送 |

为减少漏发和重复消息，任务还会：

- 每 15 分钟检查是否需要补发
- 每天最多自动发送一次
- 清理异常中断超过 30 分钟的旧任务锁

这是本机自动化，不是云端服务。电脑关机期间无法在预定时间立即发送消息。

## 常用操作

直接告诉 Codex：

```text
把摘要改成每天上午 9 点发送
把摘要写得更短一些
预览今天的摘要
测试发送一次
显示当前设置
停用自动推送
```

高级用户可以查看状态和日志：

```bash
~/.codex/skills/setup-follow-builders-lark/scripts/status.sh
tail -n 80 ~/.follow-builders/logs/push.log
tail -n 80 ~/.follow-builders/logs/push-error.log
```

## 故障排查

| 问题 | 建议 |
|---|---|
| 没收到摘要 | 运行 `status.sh`，确认任务已加载 |
| 飞书没有消息 | 检查 `push-error.log`，确认机器人仍在摘要群中 |
| 摘要生成失败 | 检查 Codex CLI 是否仍处于登录状态 |
| 睡眠或关机后未补发 | 登录 macOS，联网后等待最多 15 分钟 |
| 想立即测试 | 先让 Codex 预览，再确认执行一次测试发送 |

## 卸载

仅停用自动推送，保留配置和日志：

```bash
~/.codex/skills/setup-follow-builders-lark/scripts/uninstall.sh
```

彻底删除本地配置和日志：

```bash
~/.codex/skills/setup-follow-builders-lark/scripts/uninstall.sh --purge
```

执行卸载前，Codex 会请求确认。

## 隐私与权限

- 飞书凭据保留在本机
- 不会将飞书 Token 写入仓库
- 不会降低 macOS 钥匙串保护
- 飞书可见消息发送前会先请求确认
- 启用、停用和卸载定时任务前会先请求确认
- 仅使用飞书即时通讯能力发送消息和创建摘要群

## 信息来源与限制

默认信息源由 [follow-builders](https://github.com/zarazhangrui/follow-builders) 项目集中维护和更新。

当前版本刻意保持简单，不支持：

- 自行添加或删除 builders、播客和博客
- 自定义 RSS 或 JSON feed
- 任意网页抓取
- 任意 shell 命令
- Windows 或 Linux
- 云端定时运行

## License

[MIT](LICENSE)

## 致谢

- 资讯抓取和默认来源：[zarazhangrui/follow-builders](https://github.com/zarazhangrui/follow-builders)
- 飞书消息发送能力：[larksuite/cli](https://github.com/larksuite/cli)
