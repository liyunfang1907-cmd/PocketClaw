# 🦞 PocketClaw 口袋龙虾 — 便携式个人 AI 助手

> 将 AI 助手装入 U 盘，随插随用，安全加密，跨平台便携。

---

## 1. 项目概述

本项目基于 [OpenClaw](https://github.com/openclaw/openclaw)（开源个人 AI 助手）构建便携式 U 盘部署方案，实现：

- **随插随用**：插入任意电脑，双击启动，Docker 环境全自动安装
- **数据自包含**：所有配置、数据、凭证均存储在 U 盘内
- **高安全性**：AES-256-CBC 加密存储，容器安全加固，明文自动擦除
- **多提供商**：支持 12 家 AI 提供商（iFlow、智谱、DeepSeek、OpenAI、Claude 等）
- **免费可用**：推荐 iFlow 心流（免费额度、多模型聚合），备选智谱 GLM-4.7-Flash（永久免费）
- **手机访问**：局域网内手机/平板直接使用，支持 PWA 添加到主屏幕
- **全自动化**：Docker、WSL2、Git 自动安装，镜像加速自动配置
- **一键更新**：菜单内检查更新，自动下载安装新版本
- **自诊断修复**：11 项自动检查 + AI 智能分析，独立 Doctor 入口

---

## 2. 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                    U 盘 (ExFAT)                         │
│                                                         │
│  PocketClaw/                                            │
│  ├── PocketClaw.bat / .command   ← 双击启动（统一入口）  │
│  ├── Doctor.bat / .command       ← 双击诊断（独立入口）  │
│  ├── docker-compose.yml          ← 容器编排配置          │
│  ├── Dockerfile.custom           ← 自定义镜像构建        │
│  ├── VERSION                     ← 版本号（更新使用）    │
│  ├── secrets/                                           │
│  │   └── .env.encrypted          ← 加密的敏感配置        │
│  ├── config/                                            │
│  │   ├── openclaw.json           ← 主配置文件            │
│  │   ├── providers.json          ← 12 家 AI 提供商配置   │
│  │   ├── mobile.html             ← 手机聊天界面          │
│  │   ├── setup.html              ← Web 配置界面          │
│  │   └── workspace/              ← Agent 行为/人格/技能  │
│  ├── 工作区/                     ← 用户可见的 Agent 配置  │
│  ├── data/                       ← 持久化数据            │
│  │   ├── credentials/            ← 频道凭证              │
│  │   ├── sessions/               ← 会话历史              │
│  │   └── logs/                   ← 运行日志              │
│  └── scripts/                    ← 管理脚本              │
│                                                         │
│  ┌──────────── Docker 容器 ────────────┐                │
│  │  OpenClaw Gateway (:18789)          │                │
│  │  ├── AI Agent (对话引擎)            │                │
│  │  ├── WebChat UI (/chat)             │                │
│  │  └── Chromium 浏览器 (无头)         │                │
│  └─────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────┘
         │
         ▼  支持 12 家 AI 提供商
  ┌──────────────────────────────┐
  │  iFlow / 智谱 / DeepSeek     │
  │  OpenAI / Claude / Gemini…   │
  └──────────────────────────────┘
```

---

## 3. 目录结构详解

```
PocketClaw/
├── PocketClaw.bat                     # Windows 统一菜单启动器
├── PocketClaw.command                 # macOS 统一菜单启动器
├── Doctor.bat                         # Windows 独立诊断入口
├── Doctor.command                     # macOS 独立诊断入口
├── README.md                          # 本文件（项目说明）
├── 使用指南.txt                       # 用户使用指南
├── CHANGELOG.md                       # 版本变更记录
├── LICENSE.md                         # 许可证
├── VERSION                            # 版本号文件（更新检查使用）
│
├── docker-compose.yml                 # Docker 容器编排主文件
├── Dockerfile.custom                  # 自定义镜像构建
│
├── .editorconfig                      # 编辑器配置（UTF-8、LF、缩进）
├── .env.example                       # 环境变量模板（不含敏感信息）
├── .env.channels.example             # 频道配置变量参考
│
├── .github/workflows/                 # CI/CD 流程
│
├── config/
│   ├── openclaw.json                  # 主配置文件（模型、Gateway 等）
│   ├── providers.json                 # 12 家 AI 提供商配置
│   ├── doctor-system-prompt.txt       # Doctor AI 诊断提示词
│   ├── mobile.html                    # 手机聊天界面（PWA）
│   ├── setup.html                     # Web 配置界面
│   └── workspace/                     # Agent 内部工作空间
│       ├── AGENTS.md                  # Agent 行为指令
│       ├── SOUL.md                    # Agent 人格设定
│       ├── .provider                  # 当前选中提供商
│       ├── .bound_providers           # 已绑定提供商列表
│       ├── .gateway_token             # 随机访问 Token
│       └── skills/                    # 已安装的 Skills
│
├── 工作区/                            # 用户可见的 Agent 配置（v1.3.0+）
│   ├── AGENTS.md                      # Agent 行为指令（可编辑）
│   ├── SOUL.md                        # Agent 人格设定（可编辑）
│   └── skills/                        # 技能库
│
├── data/                              # 持久化数据
│   ├── credentials/                   # 频道凭证
│   ├── sessions/                      # 会话历史
│   ├── logs/                          # 运行日志
│   ├── skills/                        # 动态技能
│   └── .build_hash                    # 镜像指纹（智能构建缓存）
│
├── secrets/                           # 加密敏感文件存储
│   ├── .env.encrypted                 # AES-256-CBC 加密的 .env
│   └── master.key.example             # Key 管理建议
│
└── scripts/                           # 管理脚本
    ├── _common.sh                     # 共享函数库
    ├── _docker.sh                     # Docker 安装/镜像加速
    ├── _build.sh                      # 镜像智能构建
    ├── _update.sh                     # 版本检查/更新
    ├── _https.sh                      # HTTPS 证书管理
    ├── start.sh / start.bat           # 启动服务
    ├── stop.sh / stop.bat             # 停止服务
    ├── setup-env.sh / setup-env.bat   # 首次配置向导
    ├── encrypt-secrets.sh / encrypt.bat  # 加密 .env
    ├── decrypt-secrets.sh / decrypt.bat  # 解密 .env
    ├── change-api.sh / change-api.bat # 切换 AI 提供商/API Key
    ├── backup.sh / backup.bat         # 备份到本地电脑
    ├── doctor.sh / doctor.bat         # 自诊断修复（11 项检查）
    ├── setup-channels.sh / setup-channels.bat  # 频道配置向导
    ├── update.bat                     # Windows 版本检查+安装
    ├── reset.sh / reset.bat           # 完全重置
    ├── install-update.sh / install-update.bat  # 安装更新包
    ├── create-update.sh               # 生成更新包（维护者）
    ├── entrypoint.sh                  # 容器入口脚本
    └── gateway-patch.py               # Gateway 配置补丁
```

---

## 4. 系统要求

### 4.1 宿主机最低配置

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| CPU | 双核 | 四核以上 |
| 内存 | 4 GB | 8 GB 以上 |
| Docker | Docker Desktop 4.x+ 或 Docker Engine 24+ | 最新稳定版 |
| 操作系统 | macOS 13+ / Windows 10+ (WSL2) / Ubuntu 22.04+ | macOS 或 Linux |
| 网络 | 可访问互联网 | 稳定宽带连接 |

### 4.2 软件依赖

- **必需**：Docker Desktop 或 Docker Engine + Docker Compose v2（首次启动自动安装）
- **内置**：Docker Desktop 安装包、PocketClaw 源码、Git 自动安装
- **可选**：`openssl`（用于加密配置，安装 Git 后自带）

---

## 5. 安装与首次使用

### 5.1 前置准备（每台新电脑仅需一次）

**Windows（全自动安装）：**

Windows 用户无需手动安装任何软件。首次启动 `PocketClaw.bat` 时会自动：
- 检测并启用 WSL2
- 安装 Docker Desktop（使用 U 盘内置安装包）
- 安装 Git（用于加密工具）
- 配置 Docker 镜像加速器（国内网络自动检测）

只需确保系统版本为 Windows 10 或更新。

**macOS（三级自动安装）：**

首次启动 `PocketClaw.command` 时会自动检测并安装 Docker：
1. **优先**：通过 Homebrew 安装（最快最可靠）
2. **备选**：通过 Colima 轻量级容器运行时
3. **兜底**：直接下载 Docker Desktop DMG（~600MB）

没有 Homebrew 时会自动安装 Homebrew。

**Linux：**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# 注销重新登录后生效
```

### 5.2 首次启动

1. 将 PocketClaw 文件夹拷贝到 U 盘
2. 双击 `PocketClaw.bat`（Windows）或 `PocketClaw.command`（macOS）
3. 在菜单中选择 **[1] 启动**
4. 自动进入配置向导：
   - **第 1 步**：选择 AI 提供商（推荐 iFlow 或智谱，均免费）
   - **第 2 步**：输入 API Key（脚本会自动打开获取链接）
   - **第 3 步**：设置 Master Password（加密密码）
5. 等待 Docker 镜像构建（首次约 5-8 分钟）
6. 浏览器自动打开聊天界面

### 5.3 启动流程（自动执行）

```
双击启动器
  → 检测/安装 Docker
  → 解密 .env（输入 Master Password）
  → 智能构建镜像（指纹比对，秒级二次启动）
  → docker compose up -d
  → 等待 Gateway 就绪
  → 生成随机访问 Token
  → 打开浏览器
  → 安全擦除明文 .env
```

### 5.4 代理配置（可选）

如果网络需要代理才能访问外网：

启动脚本会在首次运行时询问是否需要代理，默认地址 `http://127.0.0.1:7897`。

也可在 Docker Desktop 中手动设置：Settings → Resources → Proxies

---

## 6. 环境变量配置

首次配置通过交互式向导完成，无需手动编辑文件。

配置向导会自动生成 `.env` 文件并加密存储。如需了解变量含义，参考 `.env.example`：

```env
# ============================================
# PocketClaw 环境变量配置
# ============================================

# ---------- LLM API Keys ----------
OPENAI_API_KEY=your-api-key-here       # 由配置向导自动填写

# ---------- Gateway 安全 ----------
GATEWAY_AUTH_PASSWORD=auto-generated    # 随机生成

# ---------- 代理（可选） ----------
# HTTP_PROXY=http://127.0.0.1:7897
```

> ⚠️ **安全提醒**：`.env` 文件包含所有敏感信息。启动脚本会自动加密存储、安全擦除明文。

---

## 7. AI 提供商配置

### 7.1 支持的提供商（12 家）

| 提供商 | 推荐模型 | 价格 | 特点 |
|--------|---------|------|------|
| **iFlow 心流** | DeepSeek V3.2, Qwen3, Kimi K2 | 免费 | 多模型聚合，推荐首选 |
| **智谱 AI** | GLM-4.7-Flash | 免费 | 200K 上下文，默认配置 |
| **硅基流动** | DeepSeek, Qwen, GLM | 免费 | 开源模型聚合 |
| **DeepSeek** | V3, R1 | 付费 | 性价比最高 |
| **OpenAI** | GPT-4o, o3-mini, GPT-4.1 | 付费 | 业界标杆 |
| **Anthropic** | Claude Sonnet 4, Opus 4 | 付费 | 长文本能力 |
| **Google** | Gemini 2.5 Flash/Pro | 付费 | 多模态强 |
| **xAI** | Grok 3, Grok 3 Mini | 付费 | — |
| **Moonshot** | Kimi moonshot-v1 | 付费 | 128K 上下文 |
| **通义千问** | Qwen-Turbo/Plus/Max | 付费 | 阿里云 |
| **零一万物** | Yi-Lightning, Yi-Large | 付费 | 高性能 |
| **智谱付费** | GLM-4-Plus, GLM-4-Long | 付费 | 1M 超长上下文 |

### 7.2 切换提供商

**方法一**：通过菜单切换（推荐）
- Windows：`PocketClaw.bat` → 选 **[4]**
- macOS：`PocketClaw.command` → 选 **[4]**

**方法二**：运行脚本
```bash
bash scripts/change-api.sh          # macOS/Linux
scripts\change-api.bat              # Windows
```

脚本会引导你选择提供商、输入 API Key，自动重新加密并可选重启容器。

### 7.3 提供商配置文件

所有提供商的 API 地址、默认模型、可用模型列表定义在 `config/providers.json` 中。
运行时的当前选择记录在 `config/workspace/.provider` 中。

---

## 8. 安全策略

### 8.1 威胁模型

本项目的安全设计基于以下威胁场景：

| 威胁等级 | 场景 | 防护状态 |
|---------|------|---------|
| **已防护** | U 盘丢失/被盗 | AES-256-CBC + PBKDF2 加密 |
| **已防护** | 进程列表嗅探 (`ps aux` / `wmic process`) | 所有 openssl 调用使用 `-pass stdin` |
| **已防护** | 肩窥密码输入 | Windows 使用 PowerShell SecureString 掩码 |
| **已防护** | 容器提权攻击 | `cap_drop: ALL` + `no-new-privileges` |
| **已防护** | Fork 炸弹 / 内存耗尽 | `pids_limit: 128` + `mem_limit: 2g` |
| **已防护** | 明文残留取证恢复 | 随机数覆写后删除（ExFAT 最佳努力） |
| **部分防护** | `docker inspect` 泄露环境变量 | 无法完全防止（Docker 固有限制） |
| **无法防护** | 宿主机安装键盘记录器 | 需物理安全保障 |

> **重要**：如果攻击者完全控制宿主机（root 权限），任何软件层面的防护都无法完全阻止密钥提取。上述措施旨在最大化攻击难度。

### 8.2 敏感信息加密

U 盘可能丢失或被他人拿到，因此**所有敏感信息必须加密存储**。

**加密方案：OpenSSL AES-256-CBC + PBKDF2**

```bash
# 加密（自动脚本，密码仅通过 stdin 传递，不可被 ps aux 看到）
bash scripts/encrypt-secrets.sh

# 解密
bash scripts/decrypt-secrets.sh

# Windows:
scripts\encrypt.bat
scripts\decrypt.bat
```

**安全机制细节：**
- 密码传递：`printf '%s' "$PASS" | openssl ... -pass stdin`（`printf` 是 shell 内置命令，不创建进程）
- Windows 密码输入：`PowerShell Read-Host -AsSecureString`（屏幕显示 `***`）
- 明文 .env 生命周期：仅在容器启动瞬间存在，启动后立即安全擦除
- 安全擦除：先用加密级随机数覆写文件内容，再删除（防止 ExFAT 磁盘取证恢复）
- 密码变量清理：使用 `trap ... EXIT` 确保异常退出时也清理内存中的密码

**流程**：每次启动 PocketClaw 前先解密 `.env`，使用完毕后立即删除明文并重新加密。
启动脚本 `scripts/start.sh` 会自动处理此流程。

---

### 8.3 容器安全加固

Docker 容器安全策略（docker-compose.yml 中已配置）：

- `read_only: true` — 根文件系统只读
- `security_opt: no-new-privileges` — 禁止提权
- `cap_drop: ALL` — 丢弃所有 Linux capabilities
- `mem_limit: 2g` — 内存上限 2GB
- `pids_limit: 128` — 进程数上限，防止 fork 炸弹
- `tmpfs` — /tmp、/var/log 等隔离到临时文件系统
- 非 root 用户（node）运行

**网络配置：**
- Gateway 端口绑定 `0.0.0.0:18789`（支持局域网手机访问）
- 访问需要 Token 认证（每次启动随机生成）

**已知限制（Docker 固有）：**
- `docker inspect pocketclaw` 可查看所有环境变量（包括 API Key）
- `docker exec pocketclaw env` 可查看运行时环境变量
- 如果攻击者有 Docker 访问权限，无法阻止以上操作

---

### 8.4 访问控制与 U 盘安全

**Gateway Token 认证：**

每次启动时自动生成随机 8 位 Token，访问地址格式：
```
http://127.0.0.1:18789/#token=<随机Token>
```
Token 显示在启动菜单的 `[地址]` 行中。

**U 盘物理安全建议：**
1. 使用带硬件加密的 U 盘（如 Kingston IronKey），或使用 VeraCrypt 创建加密分区
2. 拔出 U 盘前务必执行 `scripts/stop.sh` 安全关停容器
3. 不要将 U 盘长时间插在公共电脑上
4. 不要在不受信任的电脑上使用（可能有键盘记录器）
5. 定期更换所有 API Key 和密码（建议至少每3个月一次）

**停止后的残留清理：**
```bash
# 停止后清除宿主机上的 Docker 缓存
docker system prune -f
# 清除 shell history 中可能记录的敏感命令
history -c
```

---

## 9. 日常使用

### 9.1 统一菜单（推荐入口）

双击 `PocketClaw.bat`（Windows）或 `PocketClaw.command`（macOS），进入控制面板：

```
  ============================================
       PocketClaw 口袋龙虾 - 控制面板
  ============================================

  [版本] v1.3.2
  [状态] PocketClaw 运行中
  [地址] http://127.0.0.1:18789/#token=xxx
  [手机] http://192.168.0.x:18789/mobile.html#token=xxx
  [模型] iFlow 心流 / deepseek-v3.2  [正常]
  [加密] 已配置

  --------------------------------------------

    [1]  启动 PocketClaw
    [2]  停止 PocketClaw（拔U盘前必须先停止）
    [3]  打开聊天页面
    [4]  切换模型/API Key
    [5]  备份数据
    [6]  自诊断修复
    [7]  检查更新

    [0]  退出

  --------------------------------------------
```

### 9.2 启动与停止

**启动**：选菜单 [1] → 输入 Master Password → 等待容器就绪 → 浏览器自动打开

**停止**：选菜单 [2] → 容器关闭 → Docker 退出 → 清理隐藏文件 → 提示安全拔出 U 盘

**手动操作**（无需菜单）：
```bash
bash scripts/start.sh     # 启动
bash scripts/stop.sh      # 停止
```

### 9.3 切换模型/API Key

选菜单 [4]，脚本会引导你选择新的 AI 提供商、输入 API Key，自动重新加密。

### 9.4 自诊断修复

选菜单 [6]，或直接双击 `Doctor.bat`（Windows）/ `Doctor.command`（macOS），运行 11 项自动检查：
Docker 安装、引擎运行、镜像存在、容器状态、端口响应、配置完整性、API 可用性、
加密状态、磁盘空间、日志分析、网络连通性。检查完成后调用 AI 智能分析问题并给出修复建议，
支持后续对话追问。自动生成诊断报告保存到 `data/logs/`。

### 9.5 检查更新

选菜单 [7]，从 pocketclaw.cn 检查最新版本。如有更新，自动下载 ZIP 包并安装，
保留用户数据和加密配置不受影响。

### 9.6 备份

选菜单 [5]，将配置、加密文件、脚本等同步到 `~/PocketClaw_Backup/`。
自动保留最近 5 个快照，旧快照自动删除。

---

## 10. Web 界面与手机访问

### 10.1 访问地址

| 页面 | 地址 | 说明 |
|------|------|------|
| 聊天界面 | `http://127.0.0.1:18789/#token=<Token>` | 电脑端 AI 对话 |
| 手机界面 | `http://<局域网IP>:18789/mobile.html#token=<Token>` | 手机/平板专属 |
| 健康检查 | `http://127.0.0.1:18789/health` | 服务状态 |

启动后菜单会直接显示完整地址（含 Token），复制粘贴即可。

### 10.2 手机/平板访问

1. 确保手机和电脑连接**同一 WiFi**
2. 启动后菜单会显示 `[手机]` 地址
3. 在手机浏览器打开该地址

**添加到主屏幕（像 APP 一样使用）**：
- iPhone: Safari → 分享按钮 → "添加到主屏幕"
- Android: Chrome → 右上菜单 → "添加到主屏幕"

### 10.3 聊天命令速查

| 命令 | 说明 |
|------|------|
| `/status` | 查看当前会话状态（模型、Token 用量） |
| `/new` 或 `/reset` | 重置会话 |
| `/compact` | 压缩会话上下文 |
| `/think <level>` | 设置思考深度：off\|low\|medium\|high |
| `/verbose on\|off` | 开关详细模式 |

---

## 11. 聊天频道配置

除了默认的 WebChat（浏览器界面），PocketClaw 还支持接入 **10 种主流聊天软件**，让你在常用的 App 中直接与 AI 对话。

### 11.1 支持的频道总览

| 频道 | 难度 | 需要的凭证 | 说明 |
|------|------|-----------|------|
| **WebChat** | ✅ 已内置 | 无需配置 | 浏览器访问 `http://127.0.0.1:18789/chat` |
| **Telegram** | ⭐ 简单 | Bot Token | 搜索 @BotFather 创建即可，**推荐首选** |
| **Discord** | ⭐ 简单 | Bot Token | [开发者后台](https://discord.com/developers/applications) 创建 |
| **Slack** | ⭐⭐ 中等 | Bot Token + App Token | [api.slack.com/apps](https://api.slack.com/apps) 创建 |
| **WhatsApp** | ⭐⭐ 中等 | 扫码链接 + 白名单号码 | 首次启动需扫码 |
| **Signal** | ⭐⭐⭐ 复杂 | signal-cli + 手机号 | 需要额外安装 signal-cli |
| **Google Chat** | ⭐⭐⭐ 复杂 | 服务账号密钥 | 需要 Google Cloud 项目 |
| **Microsoft Teams** | ⭐⭐⭐ 复杂 | App ID + Password | 需要 Azure Bot Framework |
| **Matrix** | ⭐⭐ 中等 | Homeserver + Token | 可用 matrix.org 或自建 |
| **BlueBubbles** | ⭐⭐ 中等 | Server URL + Password | iMessage 集成，需 macOS |
| **Zalo** | ⭐⭐ 中等 | OA Access Token | 越南市场主要聊天软件 |

### 11.2 快速配置（推荐）

使用交互式向导一键配置：

```bash
# macOS / Linux
bash scripts/setup-channels.sh

# Windows
scripts\setup-channels.bat
```

向导会引导你逐步填写所需凭证，自动写入 `.env` 并重新加密。

### 11.3 手动配置

也可以直接编辑 `.env` 文件（参考 `.env.channels.example`）：

```bash
# 1. 解密 .env
bash scripts/decrypt-secrets.sh  # 或 scripts\decrypt.bat

# 2. 编辑 .env，添加频道变量（参考 .env.channels.example）
# 例：添加 Telegram
echo "TELEGRAM_BOT_TOKEN=123456:ABCdef..." >> .env

# 3. 重新加密
bash scripts/encrypt-secrets.sh  # 或 scripts\encrypt.bat

# 4. 重启生效
bash scripts/stop.sh && bash scripts/start.sh
```

### 11.4 各频道配置详情

#### Telegram（推荐）

1. 在 Telegram 中搜索 `@BotFather`
2. 发送 `/newbot`，按提示输入 Bot 名称
3. 复制生成的 Bot Token（格式：`123456:ABCdefGhI...`）
4. 填入环境变量 `TELEGRAM_BOT_TOKEN`

#### Discord

1. 打开 [Discord 开发者后台](https://discord.com/developers/applications)
2. 创建新应用 → Bot → Reset Token → 复制
3. 在 OAuth2 页面为 Bot 添加权限并邀请到服务器
4. 填入环境变量 `DISCORD_BOT_TOKEN`

#### Slack

1. 打开 [api.slack.com/apps](https://api.slack.com/apps) → 创建应用
2. OAuth & Permissions 页面获取 Bot Token（`xoxb-...`）
3. Basic Information → App-Level Tokens 获取 App Token（`xapp-...`）
4. 填入 `SLACK_BOT_TOKEN` 和 `SLACK_APP_TOKEN`

#### WhatsApp

1. 设置环境变量 `WHATSAPP_ALLOW_FROM` 为允许的手机号（含区号）
2. 启动 PocketClaw 后查看日志：`docker compose logs -f pocketclaw`
3. 用 WhatsApp 扫描终端显示的二维码完成链接

#### 其他频道

更多频道的详细配置说明请参考 OpenClaw 官方文档：
- Signal: https://docs.openclaw.ai/channels/signal
- Google Chat: https://docs.openclaw.ai/channels/googlechat
- Microsoft Teams: https://docs.openclaw.ai/channels/msteams
- Matrix: https://docs.openclaw.ai/channels/matrix
- BlueBubbles: https://docs.openclaw.ai/channels/bluebubbles

> ⚠️ **注意**：飞书（Feishu/Lark）目前 OpenClaw 上游尚未支持，后续版本可能加入。

---

## 12. 代理网络配置（可选）

如果网络需要代理才能访问外网，启动脚本会在首次运行时询问是否需要代理。

默认代理地址：`http://127.0.0.1:7897`

也可在 Docker Desktop 中手动设置：Settings → Resources → Proxies

> **提示**：国内模型（智谱、iFlow、DeepSeek 等）通常不需要代理。

---

## 13. 版本更新机制

### 13.1 在线检查更新（v1.3.2+）

在菜单中选择 **[7] 检查更新**，自动从 pocketclaw.cn 检查最新版本。

更新流程：
1. 从服务器获取 `version.json`，比较当前版本
2. 显示更新内容（changelog）
3. 用户确认后自动下载 ZIP 包
4. 解压并覆盖脚本/配置（保留用户数据不动）
5. 清理构建缓存，下次启动自动重建镜像

### 13.2 更新保护策略

| 目录/文件 | 更新时行为 | 原因 |
|-----------|-----------|------|
| `scripts/` | ✅ 覆盖更新 | 脚本修复/新功能 |
| `docker-compose.yml` | ✅ 覆盖更新 | 容器配置变更 |
| `Dockerfile.custom` | ✅ 覆盖更新 | 镜像构建变更 |
| `config/openclaw.json` | ✅ 覆盖更新 | 核心配置变更 |
| `config/providers.json` | ✅ 覆盖更新 | 提供商更新 |
| `README.md` / `使用指南.txt` | ✅ 覆盖更新 | 文档更新 |
| `secrets/` | ❌ 保留不动 | 加密密钥 |
| `data/` | ❌ 保留不动 | 会话、日志、凭证 |
| `.env` | ❌ 保留不动 | 运行时配置 |
| `config/workspace/` | ❌ 保留不动 | Agent 人格/技能 |
| `工作区/` | ❌ 保留不动 | 用户自定义内容 |

---

## 14. 备份策略

### 14.1 自动备份

在菜单中选择 **[5] 备份数据**，自动将关键文件同步到 `~/PocketClaw_Backup/`。

备份内容：`config/`、`secrets/`、`scripts/`、`docker-compose.yml`、频道凭证（可选）、会话数据（可选）。
自动保留最近 5 个快照，旧快照自动删除。

### 14.2 备份什么

| 文件/目录 | 是否备份 | 说明 |
|-----------|---------|------|
| `config/` | ✅ | 主配置、提供商配置 |
| `secrets/` | ✅ | 加密密钥 |
| `scripts/` | ✅ | 所有脚本 |
| `docker-compose.yml` | ✅ | 容器配置 |
| `工作区/` | ✅ | Agent 自定义 |
| `data/sessions/` | ⚠️ 可选 | 会话历史 |
| `data/logs/` | ❌ | 运行日志 |

---

## 15. 跨平台兼容性

U 盘使用 **ExFAT** 格式，macOS / Windows / Linux 三平台无缝切换。

| 平台 | U 盘路径 | Docker 支持 |
|------|---------|-------------|
| macOS (Apple Silicon / Intel) | `/Volumes/你的U盘/` | Docker Desktop（自动安装） |
| Windows 10/11 | `E:\` 或 `F:\` | Docker Desktop + WSL2（自动安装） |
| Ubuntu / Debian | `/media/<user>/你的U盘/` | Docker Engine |

Docker 镜像支持双架构（amd64 + arm64），自动匹配 CPU。

---

## 16. 常见问题

| 问题 | 解决方案 |
|------|---------|
| Docker 未安装 | 启动脚本自动安装，如失败参考使用指南手动安装部分 |
| 首次启动很慢 | 首次需构建镜像（5-8 分钟），后续秒级启动 |
| 无法访问聊天页 | 确认 URL 含 `#token=<Token>`，检查容器状态 |
| API 报错 | 检查 API Key 有效性、余额，选菜单 [4] 重新配置 |
| 忘记 Master Password | 无法恢复，需删除 `secrets/.env.encrypted` 重新配置 |
| U 盘拔不出 | 先选菜单 [2] 停止服务，等提示后再安全弹出 |
| 手机打不开 | 确认同一 WiFi，Windows 检查防火墙规则 |
| 更换电脑后启动慢 | 正常，每台新电脑首次需构建镜像 |

遇到复杂问题请选菜单 **[6] 自诊断修复**，自动运行 11 项检查并生成报告。

---

## 17. 参考链接

| 资源 | 链接 |
|------|------|
| PocketClaw 官网 | https://pocketclaw.cn |
| OpenClaw 官方仓库 | https://github.com/openclaw/openclaw |
| 智谱开放平台 | https://bigmodel.cn |
| iFlow 心流 | https://iflow.cn |
| Docker Desktop 下载 | https://www.docker.com/products/docker-desktop/ |

---

## 18. 版本信息

| 项目 | 值 |
|------|---|
| 当前版本 | v1.3.2 |
| 更新日期 | 2026-03-09 |
| 许可证 | 个人使用；OpenClaw: MIT License |

完整版本变更记录请查看 `CHANGELOG.md`。

---

> 📌 **快速开始三步走：**
> 1. 把 PocketClaw 文件夹拷贝到 U 盘
> 2. 双击 `PocketClaw.bat`（Windows）或 `PocketClaw.command`（macOS）
> 3. 选 [1] 启动 → 按提示配置 → 开始聊天
