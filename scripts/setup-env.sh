#!/usr/bin/env bash
# ============================================================
# setup-env.sh  —— 首次配置向导, 生成 .env 文件
# 用法: bash scripts/setup-env.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

# --------------- 颜色函数 ---------------
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
cyan()  { printf "\033[36m%s\033[0m\n" "$*"; }

trap 'unset GLM_KEY GW_PASS 2>/dev/null' EXIT

# --------------- 检查 .env 是否已存在 ---------------
if [ -f "$ENV_FILE" ]; then
    yellow "[警告] .env 已存在."
    read -rp "是否覆盖? (y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "已取消."
        exit 0
    fi
fi

echo ""
cyan "╔══════════════════════════════════════════════════╗"
cyan "║       PocketClaw 首次配置向导                  ║"
cyan "║   只需 2 步，2 分钟完成！                       ║"
cyan "╚══════════════════════════════════════════════════╝"
echo ""

# ==========================================
# 1. GLM-4.7-Flash API Key
# ==========================================
cyan "── [第 1 步] 获取免费的 AI 模型 API Key ──"
echo ""
echo "  PocketClaw 使用智谱 GLM-4.7-Flash 模型（永久免费、200K 上下文）"
echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  获取 API Key 步骤:                             │"
echo "  │                                                 │"
echo "  │  1. 打开: https://open.bigmodel.cn              │"
echo "  │  2. 点击右上角「注册/登录」, 用手机号注册       │"
echo "  │  3. 登录后进入「API密钥」页面                   │"
echo "  │     (或直接访问 https://open.bigmodel.cn/usercenter/apikeys)"
echo "  │  4. 点击「添加新的 API Key」                    │"
echo "  │  5. 输入名称（如: openclaw）, 点击确定          │"
echo "  │  6. 复制生成的 API Key                          │"
echo "  └─────────────────────────────────────────────────┘"
echo ""

GLM_KEY=""
while [ -z "$GLM_KEY" ]; do
    read -rp "  请粘贴你的 API Key: " GLM_KEY
    if [ -z "$GLM_KEY" ]; then
        red "  API Key 不能为空，请重新输入。"
    fi
done

green "  ✓ API Key 已录入"
echo ""

# ==========================================
# 生成 .env 文件
# ==========================================
cat > "$ENV_FILE" << ENVEOF
# ============================================
# PocketClaw 环境变量配置
# 由首次配置向导自动生成于 $(date '+%Y-%m-%d %H:%M:%S')
# ============================================

# ── Docker Compose 项目名 ──
COMPOSE_PROJECT_NAME=pocketclaw

# ── 模型提供商 ──
PROVIDER_NAME=zhipu

# ── 默认模型 ──
OPENCLAW_MODEL=glm-4.7-flash

# ── 智谱 AI (GLM-4.7-Flash 永久免费) ──
OPENAI_API_KEY=${GLM_KEY}

# ── Gateway 认证密码 ──
GATEWAY_AUTH_PASSWORD=pocketclaw
ENVEOF

echo ""
green "╔══════════════════════════════════════════════════╗"
green "║           ✓ 配置完成！                          ║"
green "╚══════════════════════════════════════════════════╝"
echo ""

# ==========================================
# 2. 加密 .env 文件
# ==========================================
cyan "── [第 2 步] 设置 Master Password 并加密 .env ──"
echo ""
echo "  Master Password 用于保护你的 API Key 等敏感信息。"
echo "  每次启动 PocketClaw 时需要输入此密码来解密 .env 文件。"
echo ""

ENCRYPT_SCRIPT="$SCRIPT_DIR/encrypt-secrets.sh"
if [ -f "$ENCRYPT_SCRIPT" ]; then
    if bash "$ENCRYPT_SCRIPT"; then
        # 加密成功后安全擦除明文 .env
        source "$SCRIPT_DIR/_common.sh" 2>/dev/null || true
        if type secure_wipe &>/dev/null; then
            secure_wipe "$PROJECT_DIR/.env"
        else
            rm -f "$PROJECT_DIR/.env"
        fi
        green "  ✓ .env 已加密保护"
        echo ""
        echo "  明文 .env 已安全删除，敏感信息仅存于 secrets/.env.encrypted"
    else
        yellow "  ⚠ 加密失败，.env 将以明文保存（建议稍后手动运行 encrypt-secrets.sh）"
    fi
else
    yellow "  ⚠ 未找到加密脚本，.env 将以明文保存"
fi

echo ""
echo "  接下来脚本将自动启动 PocketClaw。"
echo ""
cyan "  ┌─────────────────────────────────────────────────┐"
cyan "  │  💡 提示: 除了浏览器 WebChat，你还可以接入:     │"
echo "  │  Telegram / Discord / Slack / WhatsApp 等       │"
echo "  │  10 种聊天软件来与 AI 对话！                    │"
echo "  │                                                 │"
echo "  │  配置方法：运行 bash scripts/setup-channels.sh  │"
cyan "  └─────────────────────────────────────────────────┘"
echo ""
