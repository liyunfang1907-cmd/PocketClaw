#!/usr/bin/env bash
# ============================================================
# setup-env.sh  —— 首次配置向导, 生成 .env 文件
# 用法: bash scripts/setup-env.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

trap 'unset API_KEY GW_PASS 2>/dev/null' EXIT

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
cyan "║   只需 3 步，2 分钟完成！                       ║"
cyan "╚══════════════════════════════════════════════════╝"
echo ""

# ==========================================
# 1. 选择 AI 模型提供商
# ==========================================
cyan "── [第 1 步] 选择 AI 模型提供商 ──"
echo ""
echo "  [1] 使用智谱免费 API（推荐，无需付费）"
echo "      GLM-4.7-Flash 200K 上下文，永久免费"
echo ""
echo "  [2] 使用其他 API（需自备 API Key）"
echo "      支持 OpenAI / Gemini / Claude / Grok / DeepSeek 等"
echo ""

PROVIDER_CHOICE=""
while [[ ! "$PROVIDER_CHOICE" =~ ^[12]$ ]]; do
    read -rp "请选择 [1-2]: " PROVIDER_CHOICE
done

# ── 默认值 ──
PROV="zhipu"
PROV_NAME="智谱 AI"
DEFAULT_MODEL="glm-4.7-flash"
KEY_URL="https://open.bigmodel.cn/usercenter/apikeys"

if [ "$PROVIDER_CHOICE" = "2" ]; then
    echo ""
    echo "  选择 AI 提供商:"
    echo ""
    echo "   [1] 智谱 AI (付费高级)    GLM-4-Plus / GLM-4-Long"
    echo "   [2] DeepSeek              DeepSeek-V3 / R1 (性价比最高)"
    echo "   [3] OpenAI                GPT-4o / GPT-4.1 / o3-mini"
    echo "   [4] Anthropic Claude      Claude Sonnet 4 / Opus 4"
    echo "   [5] Google Gemini         Gemini 2.5 Flash / Pro"
    echo "   [6] xAI Grok              Grok 3 / Grok 3 Mini"
    echo "   [7] Moonshot/Kimi         长文本能力强"
    echo "   [8] 通义千问 Qwen          阿里云"
    echo "   [9] 零一万物 Yi            Yi-Lightning / Yi-Large"
    echo "  [10] 硅基流动              免费开源模型聚合"
    echo ""
    SUB_CHOICE=""
    while true; do
        read -rp "  请选择 [1-10]: " SUB_CHOICE
        if [[ "$SUB_CHOICE" =~ ^([1-9]|10)$ ]]; then break; fi
    done

    case "$SUB_CHOICE" in
        1)  PROV="zhipu-pro";   PROV_NAME="智谱 AI (付费高级)";   DEFAULT_MODEL="glm-4-plus";             KEY_URL="https://open.bigmodel.cn/usercenter/apikeys" ;;
        2)  PROV="deepseek";    PROV_NAME="DeepSeek";             DEFAULT_MODEL="deepseek-chat";           KEY_URL="https://platform.deepseek.com/api_keys" ;;
        3)  PROV="openai";      PROV_NAME="OpenAI";               DEFAULT_MODEL="gpt-4o";                  KEY_URL="https://platform.openai.com/api-keys" ;;
        4)  PROV="anthropic";   PROV_NAME="Anthropic Claude";     DEFAULT_MODEL="claude-sonnet-4-20250514"; KEY_URL="https://console.anthropic.com/settings/keys" ;;
        5)  PROV="gemini";      PROV_NAME="Google Gemini";        DEFAULT_MODEL="gemini-2.5-flash";        KEY_URL="https://aistudio.google.com/apikey" ;;
        6)  PROV="xai";         PROV_NAME="xAI Grok";             DEFAULT_MODEL="grok-3-mini";             KEY_URL="https://console.x.ai" ;;
        7)  PROV="moonshot";    PROV_NAME="Moonshot/Kimi";        DEFAULT_MODEL="moonshot-v1-auto";        KEY_URL="https://platform.moonshot.cn/console/api-keys" ;;
        8)  PROV="qwen";        PROV_NAME="通义千问 Qwen";         DEFAULT_MODEL="qwen-turbo-latest";       KEY_URL="https://dashscope.console.aliyun.com/apiKey" ;;
        9)  PROV="yi";          PROV_NAME="零一万物 Yi";            DEFAULT_MODEL="yi-lightning";            KEY_URL="https://platform.lingyiwanwu.com/apikeys" ;;
        10) PROV="siliconflow"; PROV_NAME="硅基流动 SiliconFlow";   DEFAULT_MODEL="deepseek-ai/DeepSeek-V3"; KEY_URL="https://cloud.siliconflow.cn/account/ak" ;;
    esac
fi

# ==========================================
# 2. 获取 API Key
# ==========================================
cyan "── [第 2 步] 获取 ${PROV_NAME} API Key ──"
echo ""

if [ "$PROV" = "zhipu" ]; then
    echo "  PocketClaw 使用智谱 GLM-4.7-Flash 模型（永久免费、200K 上下文）"
    echo ""
    echo "  ┌─────────────────────────────────────────────────┐"
    echo "  │  获取 API Key 步骤:                             │"
    echo "  │                                                 │"
    echo "  │  1. 打开: https://open.bigmodel.cn              │"
    echo "  │  2. 点击右上角「注册/登录」, 用手机号注册       │"
    echo "  │  3. 登录后进入「API密钥」页面                   │"
    echo "  │     (或直接访问 $KEY_URL)"
    echo "  │  4. 点击「添加新的 API Key」                    │"
    echo "  │  5. 输入名称（如: openclaw）, 点击确定          │"
    echo "  │  6. 复制生成的 API Key                          │"
    echo "  └─────────────────────────────────────────────────┘"
else
    echo "  已选择: $PROV_NAME"
    echo "  默认模型: $DEFAULT_MODEL"
    echo ""
    echo "  获取 API Key: $KEY_URL"
fi
echo ""

API_KEY=""
while [ -z "$API_KEY" ]; do
    read -rp "  请粘贴你的 ${PROV_NAME} API Key: " API_KEY
    if [ -z "$API_KEY" ]; then
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
PROVIDER_NAME=${PROV}

# ── 默认模型 ──
OPENCLAW_MODEL=${DEFAULT_MODEL}

# ── AI API Key ──
OPENAI_API_KEY=${API_KEY}

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
cyan "── [第 3 步] 设置 Master Password 并加密 .env ──"
echo ""
echo "  Master Password 用于保护你的 API Key 等敏感信息。"
echo "  每次启动 PocketClaw 时需要输入此密码来解密 .env 文件。"
echo ""
echo "  密码要求: 至少 8 位，需包含字母和数字"
echo "  推荐: 12 位以上，混合大小写+数字+符号"
echo ""

ENCRYPT_SCRIPT="$SCRIPT_DIR/encrypt-secrets.sh"
if [ -f "$ENCRYPT_SCRIPT" ]; then
    if bash "$ENCRYPT_SCRIPT"; then
        # 加密成功后安全擦除明文 .env
        secure_wipe "$PROJECT_DIR/.env"
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
