# 🦞 PocketClaw — 便携式 PocketClaw 个人 AI 助手

> 将 PocketClaw 装入 U 盘，随插随用，安全加密，跨平台便携。

---

## 1. 项目概述

本项目的目标是将 [OpenClaw](https://github.com/openclaw/openclaw)（一款开源个人 AI 助手，支持多频道消息、浏览器控制等功能）部署到一个 **256GB U 盘** 中，实现：

- **随插随用**：插入任意一台电脑，自动安装 Docker 并启动
- **数据自包含**：所有配置、数据、凭证均存储在 U 盘内
- **高安全性**：敏感信息加密存储，容器隔离运行
- **友好界面**：通过 Web 管理面板配置 API Key、服务等
- **免费模型**：默认使用智谱 GLM-4.7-Flash（永久免费、200K 上下文）
- **全自动化**：Docker、WSL2、Git 自动安装，镜像加速自动配置

---

## 2. 当前 U 盘硬件信息

| 项目 | 值 |
|------|-----|
| 卷标 | TSU303 |
| 文件系统 | ExFAT |
| 总容量 | 256 GB |
| 可用空间 | ~256 GB |
| 工作目录 | `/Volumes/TSU303/PocketClaw/` |

> **ExFAT 格式**：兼容 macOS、Windows、Linux，适合跨平台携带。无需重新格式化。

---

## 3. 方案对比分析

### 3.1 原始方案：虚拟机方案

你最初的想法是在 U 盘中安装虚拟机 + PocketClaw。这个思路的出发点是对的——追求完全隔离的运行环境。常见的虚拟机选择：

| 虚拟机 | 免费 | 跨平台 | U盘便携性 |
|--------|------|--------|-----------|
| VirtualBox | ✅ | ✅ macOS/Win/Linux | ⚠️ 勉强可行 |
| VMware Workstation Player | ✅ (个人) | ❌ 仅 Win/Linux | ❌ |
| UTM (macOS) | ✅ | ❌ 仅 macOS | ❌ |
| QEMU | ✅ | ✅ | ⚠️ 需要手动配置 |

---

### 3.2 虚拟机方案的问题

虚拟机方案**技术上可行但不推荐**，原因如下：

1. **体积巨大**：虚拟磁盘镜像 (`.vdi`/`.vmdk`) 通常需要 20-40 GB，加上客户端 OS 本身占 5-10 GB
2. **性能差**：U 盘的随机读写速度远低于 SSD，虚拟机在 U 盘上运行会非常卡顿
3. **启动慢**：需要先启动完整 OS，再启动 PocketClaw，流程冗长
4. **宿主机需安装软件**：每台新电脑都需要先安装 VirtualBox 等虚拟机管理器
5. **架构兼容性**：你当前的 Mac 是 ARM64 (Apple Silicon)，虚拟机镜像如果是 x86 的，在 ARM Mac 上无法直接运行；反之亦然
6. **ExFAT 限制**：ExFAT 上单文件 >4GB 虽然支持，但虚拟磁盘的碎片化会严重影响性能

---

### 3.3 ✅ 推荐方案：Docker Compose + 便携脚本

**核心思路**：不在 U 盘中安装完整 OS，而是利用宿主机已有的 Docker 引擎，U 盘只存储：
- PocketClaw 的 `docker-compose.yml` 配置
- 加密的配置文件和凭证
- 持久化数据卷（挂载到 U 盘目录）
- 一键启动 / 停止的 Shell 脚本（macOS/Linux）和 `.bat` / `.ps1` 脚本（Windows）

**唯一前置条件**：Windows 10+ 或 macOS 13+（Docker、WSL2、Git 均会自动安装）。

---

### 3.4 Docker 方案 vs 虚拟机方案

| 对比项 | 虚拟机方案 | Docker 方案 (推荐) |
|--------|-----------|-------------------|
| U 盘占用空间 | 20-40 GB | ~2-3 GB |
| 启动时间 | 2-5 分钟 | 10-30 秒 |
| 性能开销 | 高 (完整 OS) | 低 (共享宿主内核) |
| 跨架构兼容 | ❌ ARM/x86 不通用 | ✅ Docker 自动适配 |
| 安全隔离 | ✅ 完全隔离 | ✅ 容器隔离 + 网络隔离 |
| 数据便携 | ⚠️ 大文件迁移慢 | ✅ 配置文件轻量便携 |
| 宿主机依赖 | 需安装虚拟机管理器 | 需安装 Docker |
| PocketClaw 官方支持 | ❌ 无官方镜像 | ✅ 官方提供 Dockerfile |

---

## 4. 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                    U 盘 (256GB ExFAT)                    │
│                                                         │
│  PocketClaw/                                          │
│  ├── docker-compose.yml          ← 容器编排配置          │
│  ├── .env.example                ← 环境变量模板            │
│  ├── secrets/                                            │
│  │   └── .env.encrypted          ← 加密的敏感配置        │
│  ├── config/                                            │
│  │   ├── openclaw.json           ← PocketClaw 主配置       │
│  │   └── workspace/              ← Agent 工作区          │
│  ├── data/                                              │
│  │   ├── credentials/            ← 频道凭证 (加密)       │
│  │   └── sessions/               ← 会话数据              │
│  ├── scripts/                                           │
│  │   ├── start.sh                ← macOS/Linux 启动脚本  │
│  │   ├── start.bat               ← Windows 启动脚本      │
│  │   ├── stop.sh                 ← macOS/Linux 停止脚本  │
│  │   └── setup-env.sh            ← 首次配置向导          │
│  └── README.md                   ← 本文件                │
│                                                         │
│  ┌──────────── Docker 容器 ────────────┐                │
│  │  PocketClaw Gateway (:18789)          │                │
│  │  ├── Pi Agent (AI 对话引擎)          │                │
│  │  └── WebChat UI (:18789/chat)       │                │
│  └─────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────┐
  │  智谱 GLM-4    │
  │  (永久免费)   │
  └──────────────┘
```

---

## 5. 目录结构详解

```
PocketClaw/
├── README.md                          # 本文件（项目说明）
├── 注意事项.md                        # 使用注意事项
├── LICENSE.md                         # 许可证
│
├── docker-compose.yml                 # Docker 容器编排主文件
├── Dockerfile.custom                  # 自定义镜像构建（含代理配置等）
│
├── .env.example                       # 环境变量模板（不含敏感信息）
├── .env                               # 实际环境变量（运行时生成，.gitignore）
├── .gitignore                         # Git 忽略规则
│
├── config/
│   ├── openclaw.json                  # PocketClaw 主配置文件
│   └── workspace/                     # Agent 工作区
│       ├── AGENTS.md                  # Agent 行为指令
│       ├── SOUL.md                    # Agent 人格设定
│       └── skills/                    # 已安装的 Skills
│
├── data/                              # 持久化数据（Docker Volume 挂载点）
│   ├── credentials/                   # 频道凭证
│   ├── sessions/                      # 会话历史
│   └── logs/                          # 运行日志
│
├── secrets/                           # 加密敏感文件存储
│   └── .env.encrypted                 # AES-256-CBC 加密的 .env 文件
│
├── VERSION                            # 版本号文件 (远程更新使用)
│
└── scripts/                           # 便携启动/管理脚本
    ├── start.sh / start.bat           # 一键启动
    ├── stop.sh / stop.bat             # 一键停止
    ├── setup-env.sh / setup-env.bat   # 首次运行配置向导
    ├── encrypt-secrets.sh / encrypt.bat  # 加密 .env
    ├── decrypt-secrets.sh / decrypt.bat  # 解密 .env
    ├── change-api.bat                 # 修改 API Key
    ├── status.bat                     # 查看容器状态
    ├── logs.bat                       # 查看日志
    ├── backup.sh / backup.bat         # 备份
    ├── reset.bat                      # 重置服务
    ├── update.bat                     # 更新 PocketClaw
    ├── verify-integrity.sh             # SHA-256 完整性校验
    ├── create-update.sh               # 生成更新包 (维护者)
    ├── install-update.bat             # 安装更新包 (Windows)
    └── install-update.sh              # 安装更新包 (macOS/Linux)
```

---

## 6. 系统要求

### 6.1 宿主机最低配置

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| CPU | 双核 | 四核以上 |
| 内存 | 4 GB | 8 GB 以上 |
| Docker | Docker Desktop 4.x+ 或 Docker Engine 24+ | 最新稳定版 |
| 操作系统 | macOS 13+ / Windows 10+ (WSL2) / Ubuntu 22.04+ | macOS 或 Linux |
| 网络 | 可访问互联网 | 稳定宽带连接 |

### 6.2 软件依赖

- **必需**：Docker Desktop 或 Docker Engine + Docker Compose v2（首次启动自动安装）
- **内置**：Docker Desktop 安装包、PocketClaw 源码、Git 自动安装
- **可选**：`openssl`（用于加密配置，安装 Git 后自带）

---

## 7. 安装步骤

### 7.1 前置准备（每台新电脑仅需一次）

**Windows（v1.0.3 全自动安装）：**

Windows 用户无需手动安装任何软件。首次启动 `PocketClaw.bat` 时会自动：
- 检测并启用 WSL2
- 安装 Docker Desktop（使用 U 盘内置安装包）
- 安装 Git
- 配置 Docker 镜像加速器

只需确保系统版本为 Windows 10 或更新。

**macOS：**

需要手动安装 Docker Desktop：
```bash
brew install --cask docker
```
镜像加速器会在首次启动时自动检测并配置。

**Linux：**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# 注销重新登录后生效
```

---

### 7.2 Docker Desktop 代理配置（如需翻墙访问 GitHub）

如果当前网络需要代理才能访问 GitHub / Docker Hub：

1. 打开 Docker Desktop → Settings → Resources → Proxies
2. 启用 Manual proxy configuration
3. 填入：
   - HTTP Proxy: `http://127.0.0.1:7897`
   - HTTPS Proxy: `http://127.0.0.1:7897`
4. Apply & Restart

或在终端设置临时代理：

```bash
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export ALL_PROXY=socks5://127.0.0.1:7897
```

---

### 7.3 初始化项目

v1.0.3 已预置 PocketClaw 源码（`openclaw-src/`）和完整目录结构，无需手动初始化。

首次运行 `PocketClaw.bat`（Windows）或 `PocketClaw.command`（macOS）时，启动脚本会自动：
1. 检查并下载源码（如 U 盘中不存在）
2. 创建所需目录结构
3. 引导配置向导

> **注意**：`openclaw-src/` 只是用于 Docker 构建的源码，实际运行的 PocketClaw 在容器内部。

---

### 7.4 Docker Compose 配置

以下是 `docker-compose.yml` 的完整内容（会在项目初始化时自动生成）：

```yaml
# docker-compose.yml — PocketClaw 便携部署
version: "3.8"

services:
  pocketclaw:
    build:
      context: ./openclaw-src
      dockerfile: Dockerfile
    container_name: pocketclaw
    restart: unless-stopped
    ports:
      - "127.0.0.1:18789:18789"    # Gateway（仅本机可访问）
    volumes:
      # 将 U 盘中的配置和数据挂载到容器内
      - ./config/openclaw.json:/root/.openclaw/openclaw.json:ro
      - ./config/workspace:/root/.openclaw/workspace
      - ./data/credentials:/root/.openclaw/credentials
      - ./data/sessions:/root/.openclaw/sessions
      - ./data/logs:/root/.openclaw/logs
    env_file:
      - .env
    environment:
      - NODE_ENV=production
    networks:
      - pocketclaw-net
    security_opt:
      - no-new-privileges:true    # 安全加固：禁止提权
    read_only: false               # PocketClaw 需要写入部分运行时文件
    tmpfs:
      - /tmp:size=100M             # 限制临时文件大小

networks:
  pocketclaw-net:
    driver: bridge
    internal: false                # 需要访问外部 API
```

---

## 8. 环境变量配置

### 8.1 `.env.example` 模板

将 `.env.example` 复制为 `.env` 并填入实际值：

```bash
cp .env.example .env
```

```env
# ============================================
# PocketClaw 环境变量配置
# ============================================

# ---------- LLM API Keys ----------
# 智谱 GLM (默认，GLM-4.7-Flash 永久免费)
ZHIPU_API_KEY=your-zhipu-api-key-here

# ---------- Gateway 安全 ----------
GATEWAY_AUTH_PASSWORD=your-strong-password-here
GATEWAY_BIND=loopback

# ---------- 代理（可选） ----------
# HTTP_PROXY=http://127.0.0.1:7897
# HTTPS_PROXY=http://127.0.0.1:7897
```

> ⚠️ **安全提醒**：`.env` 文件包含所有敏感信息，务必使用加密存储（详见第 10 节安全策略）。

---

## 9. API 模型配置详解

### 9.1 智谱 GLM 配置（默认）

v1.0.3 默认使用智谱 GLM-4.7-Flash（永久免费）。首次启动时配置向导会引导你输入 API Key。

1. 前往 [智谱开放平台](https://bigmodel.cn) 注册账号
2. 在控制台创建 API Key
3. 启动时按提示输入即可

配置文件 `config/openclaw.json` 中的默认配置：

```jsonc
{
  "agent": {
    "model": "zhipu/glm-4.7-flash",
    "providers": {
      "zhipu": {
        "apiKey": "${ZHIPU_API_KEY}"
      }
    }
  }
}
```

### 9.2 其他模型提供商（高级）

PocketClaw 支持多种模型提供商，如需使用其他模型，可修改 `config/openclaw.json` 中的 provider 配置。
常见可选提供商：DeepSeek、MiniMax、Kimi (Moonshot) 等。具体配置方法请参考 [PocketClaw 官方文档](https://docs.openclaw.ai/)。

---

## 10. 安全策略

### 10.1 威胁模型

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

### 10.2 敏感信息加密

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

### 10.3 容器安全加固

Docker 容器安全策略：

```yaml
# docker-compose.yml 中的安全配置
security_opt:
  - no-new-privileges:true    # 禁止容器内提权
cap_drop:
  - ALL                       # 丢弃所有 Linux capabilities
cap_add:
  - NET_BIND_SERVICE          # 仅保留端口绑定能力
mem_limit: 2g                 # 内存上限 2GB
pids_limit: 128               # 进程数上限，防止 fork 炸弹
tmpfs:
  - /tmp:size=100M,noexec,nosuid  # 临时文件禁止执行
```

**网络隔离：**
- Gateway 端口绑定 `127.0.0.1:18789`，同一局域网的其他设备无法访问
- Docker bridge 网络隔离容器间通信

**已知限制（Docker 固有）：**
- `docker inspect pocketclaw` 可查看所有环境变量（包括 API Key）
- `docker exec pocketclaw env` 可查看运行时环境变量
- 如果攻击者有 Docker 访问权限，无法阻止以上操作

---

### 10.4 访问控制与 U 盘安全

**Gateway 密码保护：**
```jsonc
// config/openclaw.json
{
  "gateway": {
    "bind": "loopback",                    // 仅本机访问
    "auth": {
      "mode": "password",                  // 需要密码才能访问 WebChat/控制面板
      "password": "${GATEWAY_AUTH_PASSWORD}"
    }
  }
}
```

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

## 11. 日常使用指南

### 11.1 一键启动（macOS/Linux）

```bash
# 插入 U 盘后，进入项目目录
cd /Volumes/TSU303/PocketClaw   # macOS
# 或 cd /media/你的用户名/TSU303/PocketClaw  # Linux

# 运行启动脚本
bash scripts/start.sh
```

**`scripts/start.sh` 的工作流程：**
1. 检查 Docker 是否运行
2. 解密 `secrets/.env.encrypted` → `.env`（提示输入密码）
3. 执行 `docker compose up -d` 启动容器
4. 等待 Gateway 就绪
5. 自动打开浏览器访问 `http://127.0.0.1:18789`
6. 删除明文 `.env`

### 11.2 停止服务

```bash
bash scripts/stop.sh
```

**`scripts/stop.sh` 的工作流程：**
1. 执行 `docker compose down`
2. 删除残留的明文 `.env`（如有）
3. 清理 Docker 缓存
4. 提示可以安全拔出 U 盘

### 11.3 Windows 下的启动

```cmd
:: 双击 scripts\start.bat 或在命令行执行：
cd E:\PocketClaw
scripts\start.bat
```

---

## 12. Web 管理界面

PocketClaw 自带 Web 控制面板和 WebChat 界面，启动后即可通过浏览器访问。

### 12.1 访问地址

| 页面 | 地址 | 说明 |
|------|------|------|
| 控制面板 | `http://127.0.0.1:18789` | 查看状态、管理配置 |
| WebChat | `http://127.0.0.1:18789/chat` | 直接与 AI 对话 |
| 健康检查 | `http://127.0.0.1:18789/health` | 检查服务是否正常 |

### 12.2 可在 Web 界面完成的操作

- 查看 Gateway 运行状态和已连接的频道
- 与 AI 助手对话（WebChat）
- 查看会话历史
- 使用聊天命令管理（如 `/status`、`/new`、`/compact`）
- 切换模型和思考级别

### 12.3 聊天命令速查

| 命令 | 说明 |
|------|------|
| `/status` | 查看当前会话状态（模型、Token 用量） |
| `/new` 或 `/reset` | 重置会话 |
| `/compact` | 压缩会话上下文 |
| `/think <level>` | 设置思考深度：off\|low\|medium\|high |
| `/verbose on\|off` | 开关详细模式 |

---

## 13. 聊天频道配置

除了默认的 WebChat（浏览器界面），PocketClaw 还支持接入 **10 种主流聊天软件**，让你在常用的 App 中直接与 AI 对话。

### 13.1 支持的频道总览

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

### 13.2 快速配置（推荐）

使用交互式向导一键配置：

```bash
# macOS / Linux
bash scripts/setup-channels.sh

# Windows
scripts\setup-channels.bat
```

向导会引导你逐步填写所需凭证，自动写入 `.env` 并重新加密。

### 13.3 手动配置

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

### 13.4 各频道配置详情

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

## 14. 代理网络配置

当前电脑访问 GitHub 需要代理 `127.0.0.1:7897`，以下是各环节的代理配置方法。

### 14.1 Git 克隆时使用代理

```bash
git clone --depth 1 \
  -c http.proxy=http://127.0.0.1:7897 \
  -c https.proxy=http://127.0.0.1:7897 \
  https://github.com/openclaw/openclaw.git openclaw-src
```

### 14.2 Docker 构建时使用代理

在 `docker-compose.yml` 的 build 段添加：

```yaml
services:
  pocketclaw:
    build:
      context: ./openclaw-src
      dockerfile: Dockerfile
      args:
        - HTTP_PROXY=http://host.docker.internal:7897
        - HTTPS_PROXY=http://host.docker.internal:7897
```

> `host.docker.internal` 是 Docker Desktop 提供的特殊地址，指向宿主机的 `127.0.0.1`。

### 14.3 容器运行时使用代理

如果容器内的 API 调用也需要代理（通常国内模型 API 不需要）：

```yaml
environment:
  - HTTP_PROXY=http://host.docker.internal:7897
  - HTTPS_PROXY=http://host.docker.internal:7897
  - NO_PROXY=localhost,127.0.0.1,open.bigmodel.cn
```

---

## 15. 远程更新机制

### 15.1 功能概述

本项目支持远程更新：维护者在本地修改代码后，生成一个更新包（zip），发送给使用 U 盘的朋友，朋友双击安装即可获得最新版本。

**核心特性：**
- **一键安装**：朋友解压后双击 `install-update.bat` 即可
- **数据安全**：更新不影响朋友的加密配置、会话数据、Agent 人设
- **自动回滚**：安装前自动备份被替换的文件，出问题可恢复
- **自动定位**：安装器自动扫描 U 盘位置，无需手动输入路径

### 15.2 维护者工作流程

```bash
# 1. 在本地备份目录（或 U 盘）上修改代码
cd ~/PocketClaw_Backup/v1.0.2/

# 2. 修改完成后，更新 VERSION 文件
echo "1.0.3" > VERSION

# 3. 生成更新包
bash scripts/create-update.sh
# 输入新版本号、更新说明
# 输出: ~/PocketClaw_Update_v1.0.2.zip

# 4. 将 zip 发送给朋友（微信、邮件等）
```

### 15.3 朋友安装流程

```
1. 收到 zip 文件
2. 解压到桌面或任意位置
3. 插入 U 盘
4. 双击 install-update.bat (Windows) 或 bash install-update.sh (Mac)
5. 安装器自动找到 U 盘 → 确认 → 安装完成
6. 可选择立即启动 PocketClaw
```

### 15.4 更新包结构

```
PocketClaw_Update_v1.0.2/
├── install-update.bat     ← 朋友双击这个 (Windows)
├── install-update.sh      ← macOS/Linux
├── UPDATE_INFO.txt        ← 更新说明（版本号、日期、changelog）
└── _payload/              ← 更新文件（镜像项目结构，不含用户数据）
    ├── VERSION
    ├── docker-compose.yml
    ├── scripts/
    │   ├── start.bat
    │   └── ...
    └── config/
        └── openclaw.json
```

### 15.5 更新保护策略

| 目录/文件 | 更新时行为 | 原因 |
|-----------|-----------|------|
| `scripts/` | ✅ 覆盖更新 | 脚本修复/新功能 |
| `docker-compose.yml` | ✅ 覆盖更新 | 容器配置变更 |
| `Dockerfile.custom` | ✅ 覆盖更新 | 镜像构建变更 |
| `README.md` / `注意事项.md` | ✅ 覆盖更新 | 文档更新 |
| `config/openclaw.json` | ✅ 覆盖更新 | 核心配置变更 |
| `secrets/` | ❌ 保留不动 | 朋友的加密密钥 |
| `data/` | ❌ 保留不动 | 会话、日志、凭证 |
| `.env` | ❌ 保留不动 | 运行时配置 |
| `openclaw-src/` | ❌ 保留不动 | 朋友本地已有源码 |
| `config/workspace/` | ❌ 保留不动 | Agent 人格/技能定制 |

### 15.6 回滚

如果更新后出现问题：
```
1. 进入 U 盘目录: data\_rollback_v旧版本号\
2. 将里面的文件复制回 PocketClaw 根目录即可
```

---

## 16. 备份策略

### 16.1 备份位置

| 备份类型 | 存储位置 | 说明 |
|---------|---------|------|
| 本地备份 | `~/PocketClaw_Backup/` | 本机硬盘备份 |
| U 盘原始 | `/Volumes/TSU303/PocketClaw/` | 工作目录（主副本） |

> ⚠️ **备份不存储在 U 盘根目录，不上传 Git。**

### 16.2 备份什么

需要备份的关键文件：
- `config/openclaw.json` — 主配置
- `config/workspace/` — Agent 工作区和 Skills
- `secrets/.env.encrypted` — 加密的敏感配置
- `data/credentials/` — 频道凭证
- `docker-compose.yml` — 容器编排配置
- `scripts/` — 所有脚本

**不需要备份的**：
- `openclaw-src/` — 可从 GitHub 重新克隆
- `data/sessions/` — 会话历史（可选备份）
- `data/logs/` — 运行日志

### 16.3 使用备份脚本

```bash
bash scripts/backup.sh
# 自动将关键文件同步到 ~/PocketClaw_Backup/
```

---

### Q1: Docker 提示权限不足？

macOS/Linux 下可能需要将当前用户加入 docker 组：
```bash
sudo usermod -aG docker $USER
# 然后注销重新登录
```

### Q2: 容器启动后无法访问 WebChat？

1. 检查容器状态：`docker compose ps`
2. 查看日志：`docker compose logs pocketclaw`
3. 确认端口未被占用：`lsof -i :18789`

### Q3: API 调用返回超时？

- 检查网络连接和代理设置
- 国内模型（智谱 GLM）通常不需要代理
- 确认 API Key 有效且余额充足

### Q4: U 盘更换电脑后需要重新构建镜像吗？

是的，每台新电脑首次使用时需要 `docker compose build` 构建一次镜像（约 5-10 分钟）。构建完成后，后续启动只需 `docker compose up -d`。

### Q5: 如何更新 PocketClaw 版本？

```bash
cd openclaw-src
git pull origin main
cd ..
docker compose build --no-cache
docker compose up -d
```

### Q6: 忘记了加密密码怎么办？

无法恢复。需要删除 `secrets/.env.encrypted`，从 `.env.example` 重新创建并重新填入所有密钥。
**建议将加密密码记录在安全的密码管理器中。**

---

## 17. 跨平台兼容性

### 17.1 U 盘文件系统

本 U 盘使用 **ExFAT** 格式，天然支持 macOS / Windows / Linux 读写，无需额外驱动。

### 17.2 各平台注意事项

| 平台 | U 盘挂载路径示例 | Docker 支持 | 注意事项 |
|------|----------------|-------------|---------|
| macOS (Apple Silicon) | `/Volumes/TSU303/` | Docker Desktop | `host.docker.internal` 可用 |
| macOS (Intel) | `/Volumes/TSU303/` | Docker Desktop | 同上 |
| Windows 10/11 | `E:\` 或 `F:\` 等 | Docker Desktop + WSL2 | 需从 WSL2 内访问 U 盘：`/mnt/e/` |
| Ubuntu/Debian | `/media/<user>/TSU303/` | Docker Engine | 需手动安装 Docker Compose v2 |
| Fedora/Arch | `/run/media/<user>/TSU303/` | Docker Engine | 同上 |

### 17.3 架构兼容性

Docker 镜像支持多架构（`linux/amd64` + `linux/arm64`），构建时 Docker 会自动选择匹配当前 CPU 的版本：
- Apple Silicon Mac → `linux/arm64`
- Intel Mac / Windows / 大多数 Linux → `linux/amd64`

---

## 18. 参考链接

| 资源 | 链接 |
|------|------|
| OpenClaw 官方仓库 | https://github.com/openclaw/openclaw |
| PocketClaw 文档 | https://docs.openclaw.ai/ |
| PocketClaw Docker 指南 | https://docs.openclaw.ai/install/docker |
| 智谱开放平台 | https://bigmodel.cn |
| Docker Desktop 下载 | https://www.docker.com/products/docker-desktop/ |

---

## 19. 版本信息

| 项目 | 版本/日期 |
|------|----------|
| 本方案文档版本 | v1.1.0 |
| 创建日期 | 2026-02-25 |
| 安全加固日期 | 2026-02-25 |
| 远程更新功能 | 2026-02-25 |
| 完整性校验 & 汉化 | 2026-02-26 |
| GLM 简化 & 全自动安装 | 2026-02-26 |
| 多频道聊天支持 | 2026-02-28 |
| PocketClaw 目标版本 | 2026.2.24 (latest stable) |
| 许可证 | 本部署方案：个人使用；PocketClaw：MIT License |

### 19.1 v1.1.0 更新内容

- [x] 新增 10 种聊天频道支持：Telegram、Discord、Slack、WhatsApp、Signal、Google Chat、Microsoft Teams、Matrix、BlueBubbles (iMessage)、Zalo
- [x] 新增 `setup-channels.sh` / `setup-channels.bat` 频道配置向导
- [x] 新增 `.env.channels.example` 频道变量参考文件
- [x] `entrypoint.sh` 重构：动态读取频道环境变量，自动生成 channels JSON 配置
- [x] `docker-compose.yml` 新增 15 个频道相关环境变量
- [x] `setup-env.sh` / `setup-env.bat` 末尾添加频道配置提示
- [x] `AGENTS.md` 更新频道能力列表（3→11 种）
- [x] README 新增第 13 章「聊天频道配置」

### 19.2 v1.0.3 更新内容

- [x] 简化为智谱 GLM-4.7-Flash 单模型（永久免费）
- [x] Windows 全自动安装：Docker Desktop、WSL2、Git 自动检测并安装
- [x] Docker 镜像加速器自动检测并配置（国内网络）
- [x] 内置 Docker Desktop 安装包和 PocketClaw 源码，减少网络依赖
- [x] UX 优化：构建进度提示、日志记录、友好错误信息
- [x] 移除 Telegram/Email 冗余配置脚本
- [x] 文档整合：删除 QUICKSTART_WINDOWS.md，统一使用使用指南.txt

### 19.3 v1.0.2 更新内容

- [x] 新增 `LICENSE.md` 开源许可证
- [x] 新增 `verify-integrity.sh` SHA-256 完整性校验
- [x] 全部脚本界面汉化（67+ 处英文标签改为中文）

### 19.4 v1.0.1 更新内容

- [x] 新增远程更新机制：`create-update.sh` 生成更新包，朋友一键安装
- [x] 新增 `install-update.bat` / `install-update.sh` 更新安装器
- [x] 新增 `VERSION` 版本追踪文件
- [x] 自动扫描 U 盘位置、回滚备份、数据保护

### 19.5 v1.0.0 安全加固清单

- [x] 修复 openssl `-pass pass:` 密码在进程列表中泄露（所有脚本改用 `-pass stdin`）
- [x] Windows 密码输入改用 PowerShell `SecureString` 掩码显示
- [x] Docker 容器加固：`cap_drop: ALL` + `mem_limit` + `pids_limit` + `tmpfs noexec`
- [x] Dockerfile.custom 添加非 root 用户支持
- [x] 明文 .env 安全擦除：加密级随机数覆写后删除（防磁盘取证）
- [x] 修复 `docker compose` v1/v2 检测逻辑错误
- [x] 修复 `set -e` 导致的密码变量清理死代码
- [x] 添加 `trap ... EXIT` 确保异常退出时清理所有敏感变量
- [x] 修复 change-*.bat 重新加密失败时数据丢失风险
- [x] 修复 docker compose restart 缺少 `-f` 参数
- [x] 安全擦除升级为 `[Security.Cryptography.RandomNumberGenerator]`
- [x] 密码随机生成改用加密级随机源

---

> 📌 **快速开始三步走：**
> 1. 确保电脑已安装 Docker Desktop
> 2. 运行 `bash scripts/start.sh`
> 3. 打开浏览器访问 `http://127.0.0.1:18789/chat`
