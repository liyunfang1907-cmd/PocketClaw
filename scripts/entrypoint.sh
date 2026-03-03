#!/bin/bash
# ============================================================
# PocketClaw Entrypoint
# 根据环境变量/配置文件动态生成 openclaw.json，然后启动 OpenClaw
# 支持多厂商一键切换：智谱/DeepSeek/Moonshot/通义千问/零一万物/硅基流动
# ============================================================
set -e

CONFIG_DIR="/home/node/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"
WORKSPACE_PROVIDER="$CONFIG_DIR/workspace/.provider"

# ── 读取配置（优先级: workspace/.provider > 环境变量 > 默认值）──
PROVIDER="${PROVIDER_NAME:-zhipu}"
ACTIVE_KEY="${OPENAI_API_KEY:-}"
MODEL_ID="${OPENCLAW_MODEL:-}"
AUTH_PASS="${GATEWAY_AUTH_PASSWORD:-pocketclaw}"

# 向后兼容：旧版 ZHIPU_API_KEY / docker-compose 默认空值
if [[ -z "$ACTIVE_KEY" || "$ACTIVE_KEY" == "not-configured-yet" ]]; then
  if [[ -n "${ZHIPU_API_KEY:-}" ]]; then
    ACTIVE_KEY="$ZHIPU_API_KEY"
  fi
fi

# 如果 workspace/.provider 存在，优先使用
if [[ -f "$WORKSPACE_PROVIDER" ]]; then
  echo "[PocketClaw] 读取 workspace/.provider 配置..."
  while IFS='=' read -r key value; do
    # 跳过注释和空行
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
      PROVIDER_NAME) PROVIDER="$value" ;;
      API_KEY) ACTIVE_KEY="$value" ;;
      MODEL_ID) MODEL_ID="$value" ;;
    esac
  done < "$WORKSPACE_PROVIDER"
fi

# 设置 OPENAI_API_KEY 环境变量（OpenClaw 读取此变量）
export OPENAI_API_KEY="$ACTIVE_KEY"

# ── 各厂商配置 ──
case "$PROVIDER" in
  zhipu)
    BASE_URL="https://open.bigmodel.cn/api/paas/v4"
    MODEL_ID="${MODEL_ID:-glm-4.7-flash}"
    PROVIDER_LABEL="智谱 AI"
    MODELS='[
      {"id":"glm-4.7-flash","name":"GLM-4.7 Flash (旗舰免费)","input":["text"],"contextWindow":200000,"maxTokens":128000,"compat":{}},
      {"id":"glm-4-flash","name":"GLM-4 Flash (免费)","input":["text"],"contextWindow":128000,"maxTokens":4096,"compat":{}},
      {"id":"glm-z1-flash","name":"GLM-Z1 Flash (推理免费)","input":["text"],"contextWindow":128000,"maxTokens":16384,"compat":{}},
      {"id":"glm-4.6v-flash","name":"GLM-4.6V Flash (视觉免费)","input":["text","image"],"contextWindow":8192,"maxTokens":4096,"compat":{}}
    ]'
    ;;

  deepseek)
    BASE_URL="https://api.deepseek.com/v1"
    MODEL_ID="${MODEL_ID:-deepseek-chat}"
    PROVIDER_LABEL="DeepSeek"
    MODELS='[
      {"id":"deepseek-chat","name":"DeepSeek V3","input":["text"],"contextWindow":65536,"maxTokens":8192,"compat":{}},
      {"id":"deepseek-reasoner","name":"DeepSeek R1 (深度推理)","input":["text"],"contextWindow":65536,"maxTokens":8192,"compat":{}}
    ]'
    ;;

  moonshot)
    BASE_URL="https://api.moonshot.cn/v1"
    MODEL_ID="${MODEL_ID:-moonshot-v1-auto}"
    PROVIDER_LABEL="Moonshot/Kimi"
    MODELS='[
      {"id":"moonshot-v1-auto","name":"Kimi (自动选择)","input":["text"],"contextWindow":131072,"maxTokens":4096,"compat":{}},
      {"id":"moonshot-v1-8k","name":"Kimi 8K","input":["text"],"contextWindow":8192,"maxTokens":4096,"compat":{}},
      {"id":"moonshot-v1-32k","name":"Kimi 32K","input":["text"],"contextWindow":32768,"maxTokens":4096,"compat":{}},
      {"id":"moonshot-v1-128k","name":"Kimi 128K","input":["text"],"contextWindow":131072,"maxTokens":4096,"compat":{}}
    ]'
    ;;

  qwen)
    BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
    MODEL_ID="${MODEL_ID:-qwen-turbo-latest}"
    PROVIDER_LABEL="通义千问 (阿里云)"
    MODELS='[
      {"id":"qwen-turbo-latest","name":"Qwen Turbo (快速)","input":["text"],"contextWindow":131072,"maxTokens":8192,"compat":{}},
      {"id":"qwen-plus-latest","name":"Qwen Plus (均衡)","input":["text"],"contextWindow":131072,"maxTokens":8192,"compat":{}},
      {"id":"qwen-max-latest","name":"Qwen Max (旗舰)","input":["text"],"contextWindow":131072,"maxTokens":8192,"compat":{}},
      {"id":"qwen-vl-plus","name":"Qwen VL Plus (视觉)","input":["text","image"],"contextWindow":8192,"maxTokens":4096,"compat":{}}
    ]'
    ;;

  yi)
    BASE_URL="https://api.lingyiwanwu.com/v1"
    MODEL_ID="${MODEL_ID:-yi-lightning}"
    PROVIDER_LABEL="零一万物 (Yi)"
    MODELS='[
      {"id":"yi-lightning","name":"Yi Lightning (快速)","input":["text"],"contextWindow":16384,"maxTokens":4096,"compat":{}},
      {"id":"yi-large","name":"Yi Large (旗舰)","input":["text"],"contextWindow":32768,"maxTokens":4096,"compat":{}},
      {"id":"yi-medium","name":"Yi Medium (均衡)","input":["text"],"contextWindow":16384,"maxTokens":4096,"compat":{}},
      {"id":"yi-vision","name":"Yi Vision (视觉)","input":["text","image"],"contextWindow":16384,"maxTokens":4096,"compat":{}}
    ]'
    ;;

  siliconflow)
    BASE_URL="https://api.siliconflow.cn/v1"
    MODEL_ID="${MODEL_ID:-deepseek-ai/DeepSeek-V3}"
    PROVIDER_LABEL="硅基流动 SiliconFlow"
    MODELS='[
      {"id":"deepseek-ai/DeepSeek-V3","name":"DeepSeek V3 (免费)","input":["text"],"contextWindow":65536,"maxTokens":8192,"compat":{}},
      {"id":"deepseek-ai/DeepSeek-R1","name":"DeepSeek R1 (免费)","input":["text"],"contextWindow":65536,"maxTokens":8192,"compat":{}},
      {"id":"Qwen/Qwen2.5-72B-Instruct","name":"Qwen 2.5 72B (免费)","input":["text"],"contextWindow":131072,"maxTokens":8192,"compat":{}},
      {"id":"THUDM/glm-4-9b-chat","name":"GLM-4 9B (免费)","input":["text"],"contextWindow":131072,"maxTokens":4096,"compat":{}}
    ]'
    ;;

  *)
    echo "[PocketClaw] 错误: 未知的提供商 '$PROVIDER'"
    echo "[PocketClaw] 支持的提供商: zhipu, deepseek, moonshot, qwen, yi, siliconflow"
    echo "[PocketClaw] 将使用默认配置 (zhipu)"
    BASE_URL="https://open.bigmodel.cn/api/paas/v4"
    MODEL_ID="glm-4.7-flash"
    PROVIDER_LABEL="智谱 AI (默认)"
    MODELS='[
      {"id":"glm-4.7-flash","name":"GLM-4.7 Flash (旗舰免费)","input":["text"],"contextWindow":200000,"maxTokens":128000,"compat":{}}
    ]'
    ;;
esac

# ── 构建频道配置 ──
# 根据环境变量动态生成 channels JSON 片段
CHANNELS=""
ACTIVE_CHANNELS=""

# --- Telegram ---
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  CHANNELS="${CHANNELS}\"telegram\":{\"botToken\":\"${TELEGRAM_BOT_TOKEN}\"},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Telegram\n"
fi

# --- Discord ---
if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
  CHANNELS="${CHANNELS}\"discord\":{\"token\":\"${DISCORD_BOT_TOKEN}\"},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Discord\n"
fi

# --- Slack ---
if [[ -n "${SLACK_BOT_TOKEN:-}" && -n "${SLACK_APP_TOKEN:-}" ]]; then
  CHANNELS="${CHANNELS}\"slack\":{\"botToken\":\"${SLACK_BOT_TOKEN}\",\"appToken\":\"${SLACK_APP_TOKEN}\"},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Slack\n"
elif [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
  echo "[PocketClaw] ⚠ Slack 需要同时配置 SLACK_BOT_TOKEN 和 SLACK_APP_TOKEN"
fi

# --- WhatsApp ---
if [[ -n "${WHATSAPP_ALLOW_FROM:-}" ]]; then
  # WhatsApp 使用 Baileys，需要通过 openclaw channels login 链接设备
  # allowFrom 用逗号分隔的电话号码列表
  IFS=',' read -ra WA_NUMS <<< "$WHATSAPP_ALLOW_FROM"
  WA_ALLOW="["
  for num in "${WA_NUMS[@]}"; do
    num=$(echo "$num" | xargs)
    WA_ALLOW="${WA_ALLOW}\"${num}\","
  done
  WA_ALLOW="${WA_ALLOW%,}]"
  CHANNELS="${CHANNELS}\"whatsapp\":{\"allowFrom\":${WA_ALLOW}},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ WhatsApp\n"
fi

# --- Signal ---
if [[ -n "${SIGNAL_PHONE_NUMBER:-}" ]]; then
  CHANNELS="${CHANNELS}\"signal\":{\"number\":\"${SIGNAL_PHONE_NUMBER}\"},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Signal\n"
fi

# --- Google Chat ---
if [[ -n "${GOOGLE_CHAT_CREDENTIALS:-}" ]]; then
  GC_EXTRA=""
  if [[ -n "${GOOGLE_CHAT_SPACES:-}" ]]; then
    GC_EXTRA=",\"spaces\":\"${GOOGLE_CHAT_SPACES}\""
  fi
  CHANNELS="${CHANNELS}\"googlechat\":{\"serviceAccountKeyFile\":\"${GOOGLE_CHAT_CREDENTIALS}\"${GC_EXTRA}},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Google Chat\n"
fi

# --- Microsoft Teams ---
if [[ -n "${MSTEAMS_APP_ID:-}" && -n "${MSTEAMS_APP_PASSWORD:-}" ]]; then
  CHANNELS="${CHANNELS}\"msteams\":{\"appId\":\"${MSTEAMS_APP_ID}\",\"appPassword\":\"${MSTEAMS_APP_PASSWORD}\"},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Microsoft Teams\n"
elif [[ -n "${MSTEAMS_APP_ID:-}" ]]; then
  echo "[PocketClaw] ⚠ Microsoft Teams 需要同时配置 MSTEAMS_APP_ID 和 MSTEAMS_APP_PASSWORD"
fi

# --- Matrix ---
if [[ -n "${MATRIX_HOMESERVER:-}" && -n "${MATRIX_USER_ID:-}" && -n "${MATRIX_ACCESS_TOKEN:-}" ]]; then
  CHANNELS="${CHANNELS}\"matrix\":{\"homeserverUrl\":\"${MATRIX_HOMESERVER}\",\"userId\":\"${MATRIX_USER_ID}\",\"accessToken\":\"${MATRIX_ACCESS_TOKEN}\"},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Matrix\n"
elif [[ -n "${MATRIX_HOMESERVER:-}" ]]; then
  echo "[PocketClaw] ⚠ Matrix 需要同时配置 MATRIX_HOMESERVER、MATRIX_USER_ID 和 MATRIX_ACCESS_TOKEN"
fi

# --- BlueBubbles (iMessage) ---
if [[ -n "${BLUEBUBBLES_SERVER_URL:-}" && -n "${BLUEBUBBLES_PASSWORD:-}" ]]; then
  CHANNELS="${CHANNELS}\"bluebubbles\":{\"serverUrl\":\"${BLUEBUBBLES_SERVER_URL}\",\"password\":\"${BLUEBUBBLES_PASSWORD}\"},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ BlueBubbles (iMessage)\n"
elif [[ -n "${BLUEBUBBLES_SERVER_URL:-}" ]]; then
  echo "[PocketClaw] ⚠ BlueBubbles 需要同时配置 BLUEBUBBLES_SERVER_URL 和 BLUEBUBBLES_PASSWORD"
fi

# --- Zalo ---
if [[ -n "${ZALO_OA_ACCESS_TOKEN:-}" ]]; then
  CHANNELS="${CHANNELS}\"zalo\":{\"oaAccessToken\":\"${ZALO_OA_ACCESS_TOKEN}\"},"
  ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Zalo\n"
fi

# 移除末尾逗号，构建完整 channels JSON
if [[ -n "$CHANNELS" ]]; then
  CHANNELS="{${CHANNELS%,}}"
  CHANNELS_BLOCK="\"channels\": $CHANNELS,"
else
  CHANNELS_BLOCK=""
  ACTIVE_CHANNELS="  （无额外频道，仅 WebChat）\n"
fi

# ── 生成 openclaw.json（含频道配置） ──
cat > "$CONFIG_FILE" << JSONEOF
{
  "agents": {
    "defaults": {
      "model": "openai/$MODEL_ID"
    }
  },
  "models": {
    "providers": {
      "openai": {
        "baseUrl": "$BASE_URL",
        "api": "openai-completions",
        "models": $MODELS
      }
    }
  },
  $CHANNELS_BLOCK
  "gateway": {
    "port": 18789,
    "bind": "lan",
    "mode": "local",
    "controlUi": {
      "allowedOrigins": ["http://127.0.0.1:18789", "http://localhost:18789", "null", "*"],
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true
    },
    "auth": {
      "mode": "token",
      "token": "$AUTH_PASS"
    }
  },
  "tools": {
    "profile": "full"
  },
  "browser": {
    "enabled": true,
    "headless": true,
    "noSandbox": true,
    "defaultProfile": "openclaw"
  }
}
JSONEOF

# 修正：如果没有频道配置，移除多余的空行和逗号
if [[ -z "$CHANNELS_BLOCK" ]]; then
  sed -i.bak '/^  $/d' "$CONFIG_FILE" && rm -f "$CONFIG_FILE.bak"
fi

echo "============================================"
echo "  PocketClaw 启动配置"
echo "============================================"
echo "  提供商: $PROVIDER_LABEL"
echo "  模型:   $MODEL_ID"
echo "  API:    $BASE_URL"
echo "  端口:   18789"
echo "--------------------------------------------"
echo "  聊天频道:"
echo "  ✅ WebChat (内置)"
printf "$ACTIVE_CHANNELS"
echo "============================================"

# ── 将 token 写入 workspace 供 AI 读取 ──
echo "$AUTH_PASS" > "$CONFIG_DIR/workspace/.gateway_token"

# ── 注入自定义页面到 OpenClaw 前端 ──
CONTROL_UI_DIR="$(dirname "$(find /usr/local/lib/node_modules/openclaw -name index.html -path '*/control-ui/*' 2>/dev/null)" 2>/dev/null)"
MOBILE_HTML="/app/config/mobile.html"

if [ -d "$CONTROL_UI_DIR" ]; then
    # 注入手机专属页面
    if [ -f "$MOBILE_HTML" ]; then
        cp "$MOBILE_HTML" "$CONTROL_UI_DIR/mobile.html" 2>/dev/null && \
            echo "  ✅ 手机专属页面已注入" || echo "  ⚠️  手机页面注入失败"
    fi
else
    echo "  ⚠️  未找到 control-ui 目录，跳过 UI 自定义"
fi

# ── 注入自定义文件路由到 Gateway（绕过 canvasHost SPA 拦截）──
# canvasHost.handleHttpRequest 会在 handleControlUiHttpRequest 之前拦截所有页面请求，
# 导致 mobile.html 被替换为 SPA 的 index.html。此 patch 在 canvasHost 之前插入
# 一个处理器，直接从磁盘提供 mobile.html。
if [ -d "$CONTROL_UI_DIR" ]; then
    GW_DIR="$(dirname "$CONTROL_UI_DIR")"
    export CONTROL_UI_DIR GW_DIR
    python3 -c '
import os, sys, glob

gw_dir = os.environ.get("GW_DIR", "")
ui_dir = os.environ.get("CONTROL_UI_DIR", "")

# Find gateway-cli JS files
gw_files = glob.glob(os.path.join(gw_dir, "gateway-cli-*.js"))
patched = False

for gw_file in gw_files:
    try:
        with open(gw_file, "r") as f:
            content = f.read()
    except (PermissionError, OSError):
        continue

    # Skip if already patched
    if "_pocketClawCustomFiles" in content:
        patched = True
        continue

    # Find handleRequest function
    hr = content.find("async function handleRequest(req, res)")
    if hr == -1:
        continue

    # Find "if (canvasHost) {" after handleRequest
    target = content.find("if (canvasHost) {", hr)
    if target == -1:
        continue

    # Injection: serve custom files before canvasHost intercepts them
    inject = (
        "\t\t\t\t{\n"
        "\t\t\t\t\tconst _pocketClawCustomFiles = {\n"
        "\t\t\t\t\t\t\x27/mobile.html\x27: \x27text/html; charset=utf-8\x27\n"
        "\t\t\t\t\t};\n"
        "\t\t\t\t\tconst _pcMime = _pocketClawCustomFiles[requestPath];\n"
        "\t\t\t\t\tif (_pcMime) {\n"
        "\t\t\t\t\t\ttry {\n"
        "\t\t\t\t\t\t\tconst _pcFs = await import(\x27node:fs\x27);\n"
        "\t\t\t\t\t\t\tconst _pcData = _pcFs.default.readFileSync(\x27" + ui_dir.replace("\\\\", "\\\\\\\\") + "\x27 + requestPath);\n"
        "\t\t\t\t\t\t\tres.writeHead(200, { \x27Content-Type\x27: _pcMime, \x27Cache-Control\x27: \x27no-cache\x27, \x27Content-Security-Policy\x27: \"default-src \x27self\x27; script-src \x27self\x27 \x27unsafe-inline\x27; style-src \x27self\x27 \x27unsafe-inline\x27 https://fonts.googleapis.com; img-src \x27self\x27 data: https:; font-src \x27self\x27 https://fonts.gstatic.com; connect-src \x27self\x27 ws: wss:; base-uri \x27none\x27; object-src \x27none\x27; frame-ancestors \x27none\x27\" });\n"
        "\t\t\t\t\t\t\tres.end(_pcData);\n"
        "\t\t\t\t\t\t\treturn;\n"
        "\t\t\t\t\t\t} catch(_pcErr) { /* fall through */ }\n"
        "\t\t\t\t\t}\n"
        "\t\t\t\t}\n"
    )

    new_content = content[:target] + inject + content[target:]
    try:
        with open(gw_file, "w") as f:
            f.write(new_content)
        patched = True
    except (PermissionError, OSError) as e:
        print(f"  ⚠️  无法写入 {gw_file}: {e}")
        continue

if patched:
    print("  ✅ Gateway 自定义路由已注入")
else:
    print("  ⚠️  Gateway 路由注入失败（mobile.html 可能无法访问）")
' 2>&1 || echo "  ⚠️  Gateway 路由注入脚本出错"
fi

# ── 启动 OpenClaw Gateway ──
exec openclaw gateway --port 18789 --verbose
