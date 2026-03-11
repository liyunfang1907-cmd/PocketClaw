#!/bin/bash
# ============================================================
# PocketClaw Entrypoint
# 根据环境变量/配置文件动态生成 openclaw.json，然后启动 OpenClaw
# 支持多厂商一键切换：智谱/DeepSeek/Moonshot/通义千问/零一万物/硅基流动
#
# 结构: 函数定义 → main() 入口
# ============================================================
set -e

# ── 常量 ──
readonly CONFIG_DIR="/home/node/.openclaw"
readonly CONFIG_FILE="$CONFIG_DIR/openclaw.json"
readonly WORKSPACE_PROVIDER="$CONFIG_DIR/workspace/.provider"
readonly PROVIDERS_JSON="/app/config/providers.json"
readonly MOBILE_HTML="/app/config/mobile.html"
readonly GATEWAY_PATCH="/app/scripts/gateway-patch.py"
readonly GATEWAY_PORT=18789

# ── 全局变量（由函数填充） ──
PROVIDER=""
ACTIVE_KEY=""
MODEL_ID=""
AUTH_PASS=""
BASE_URL=""
PROVIDER_LABEL=""
MODELS=""
CHANNELS_BLOCK=""
ACTIVE_CHANNELS=""
CONTROL_UI_DIR=""

# ────────────────────────────────────────────────
# load_config: 读取环境变量和 workspace/.provider
# 优先级: workspace/.provider > 环境变量 > 默认值
# ────────────────────────────────────────────────
load_config() {
  PROVIDER="${PROVIDER_NAME:-zhipu}"
  ACTIVE_KEY="${OPENAI_API_KEY:-}"
  MODEL_ID="${OPENCLAW_MODEL:-}"
  AUTH_PASS="${GATEWAY_AUTH_PASSWORD:-pocketclaw}"
  # 默认占位符时自动生成随机 32 位 token（~190 bit 熵，不可暴力破解）
  if [ "$AUTH_PASS" = "pocketclaw" ]; then
    AUTH_PASS=$(< /dev/urandom tr -dc 'a-zA-Z0-9' 2>/dev/null | head -c 32)
  fi

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
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue
      key=$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r')
      value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r')
      case "$key" in
        PROVIDER_NAME) PROVIDER="$value" ;;
        API_KEY) ACTIVE_KEY="$value" ;;
        MODEL_ID) MODEL_ID="$value" ;;
      esac
    done < "$WORKSPACE_PROVIDER"
  fi

  # 设置 OPENAI_API_KEY 环境变量（OpenClaw 读取此变量）
  export OPENAI_API_KEY="$ACTIVE_KEY"
}

# ────────────────────────────────────────────────
# load_provider: 从 providers.json 读取厂商配置
# 设置 BASE_URL, MODEL_ID, PROVIDER_LABEL, MODELS
# ────────────────────────────────────────────────
load_provider() {
  if [ ! -f "$PROVIDERS_JSON" ]; then
    echo "[PocketClaw] 错误: providers.json 不存在"
    exit 1
  fi

  # P3: 优先用 jq（避免 Python 冷启动开销），回退到 Python
  if command -v jq &>/dev/null; then
    local _prov="$PROVIDER"
    # 检查提供商是否存在
    if ! jq -e ".\"$_prov\"" "$PROVIDERS_JSON" &>/dev/null; then
      local _names
      _names=$(jq -r 'keys | join(", ")' "$PROVIDERS_JSON")
      echo "[PocketClaw] 错误: 未知的提供商 $_prov"
      echo "[PocketClaw] 支持的提供商: $_names"
      echo "[PocketClaw] 将使用默认配置 (zhipu)"
      _prov="zhipu"
    fi
    BASE_URL=$(jq -r ".\"$_prov\".baseUrl" "$PROVIDERS_JSON")
    PROVIDER_LABEL=$(jq -r ".\"$_prov\".label" "$PROVIDERS_JSON")
    MODELS=$(jq -c ".\"$_prov\".models" "$PROVIDERS_JSON")
    if [ -z "$MODEL_ID" ]; then
      MODEL_ID=$(jq -r ".\"$_prov\".defaultModel" "$PROVIDERS_JSON")
    fi
  else
    # 回退: Python 解析（Q2: 用逐行 read 替代 eval）
    export _PJ="$PROVIDERS_JSON" _PN="$PROVIDER" _MI="$MODEL_ID"
    local _output
    _output=$(python3 << 'PYEOF'
import json, os

providers_file = os.environ.get("_PJ")
provider_name = os.environ.get("_PN", "zhipu")
env_model = os.environ.get("_MI", "")

with open(providers_file) as f:
    providers = json.load(f)

if provider_name not in providers:
    names = ", ".join(providers.keys())
    import sys
    print(f"WARN:[PocketClaw] 错误: 未知的提供商 {provider_name}", file=sys.stderr)
    print(f"WARN:[PocketClaw] 支持的提供商: {names}", file=sys.stderr)
    provider_name = "zhipu"

p = providers[provider_name]
model_id = env_model if env_model else p["defaultModel"]

print(f'BASE_URL={p["baseUrl"]}')
print(f'MODEL_ID={model_id}')
print(f'PROVIDER_LABEL={p["label"]}')
print(f"MODELS={json.dumps(p['models'])}")
PYEOF
    )
    # Q2: 安全解析 —— 逐行 read 替代 eval
    while IFS='=' read -r _key _val; do
      case "$_key" in
        BASE_URL) BASE_URL="$_val" ;;
        MODEL_ID) MODEL_ID="$_val" ;;
        PROVIDER_LABEL) PROVIDER_LABEL="$_val" ;;
        MODELS) MODELS="$_val" ;;
      esac
    done <<< "$_output"
    unset _PJ _PN _MI
  fi
}

# ────────────────────────────────────────────────
# build_channels: 根据环境变量构建频道 JSON 片段
# 设置 CHANNELS_BLOCK, ACTIVE_CHANNELS
# ────────────────────────────────────────────────
build_channels() {
  local channels=""
  ACTIVE_CHANNELS=""

  # C6: JSON 值转义辅助函数（转义 \ 和 "）
  _json_escape() {
    local val="$1"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    printf '%s' "$val"
  }

  # 辅助函数: 添加简单频道（单 token 类型）
  _add_simple_channel() {
    local name="$1" env_var="$2" json_key="$3" label="$4"
    local val="${!env_var:-}"
    if [[ -n "$val" ]]; then
      val=$(_json_escape "$val")
      channels="${channels}\"${name}\":{\"${json_key}\":\"${val}\"},"
      ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ ${label}\n"
    fi
  }

  # 辅助函数: 添加双参数频道
  _add_dual_channel() {
    local name="$1" env1="$2" key1="$3" env2="$4" key2="$5" label="$6"
    local val1="${!env1:-}" val2="${!env2:-}"
    if [[ -n "$val1" && -n "$val2" ]]; then
      val1=$(_json_escape "$val1")
      val2=$(_json_escape "$val2")
      channels="${channels}\"${name}\":{\"${key1}\":\"${val1}\",\"${key2}\":\"${val2}\"},"
      ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ ${label}\n"
    elif [[ -n "$val1" ]]; then
      echo "[PocketClaw] ⚠ ${label} 需要同时配置 ${env1} 和 ${env2}"
    fi
  }

  _add_simple_channel "telegram" "TELEGRAM_BOT_TOKEN" "botToken" "Telegram"
  _add_simple_channel "discord" "DISCORD_BOT_TOKEN" "token" "Discord"
  _add_dual_channel "slack" "SLACK_BOT_TOKEN" "botToken" "SLACK_APP_TOKEN" "appToken" "Slack"

  # WhatsApp（特殊: allowFrom 是数组）
  if [[ -n "${WHATSAPP_ALLOW_FROM:-}" ]]; then
    IFS=',' read -ra WA_NUMS <<< "$WHATSAPP_ALLOW_FROM"
    local wa_allow="["
    for num in "${WA_NUMS[@]}"; do
      num=$(echo "$num" | xargs)
      wa_allow="${wa_allow}\"${num}\","
    done
    wa_allow="${wa_allow%,}]"
    channels="${channels}\"whatsapp\":{\"allowFrom\":${wa_allow}},"
    ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ WhatsApp\n"
  fi

  _add_simple_channel "signal" "SIGNAL_PHONE_NUMBER" "number" "Signal"

  # Google Chat（特殊: 可选 spaces 参数）
  if [[ -n "${GOOGLE_CHAT_CREDENTIALS:-}" ]]; then
    local gc_extra=""
    [[ -n "${GOOGLE_CHAT_SPACES:-}" ]] && gc_extra=",\"spaces\":\"${GOOGLE_CHAT_SPACES}\""
    channels="${channels}\"googlechat\":{\"serviceAccountKeyFile\":\"${GOOGLE_CHAT_CREDENTIALS}\"${gc_extra}},"
    ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Google Chat\n"
  fi

  _add_dual_channel "msteams" "MSTEAMS_APP_ID" "appId" "MSTEAMS_APP_PASSWORD" "appPassword" "Microsoft Teams"

  # Matrix（三参数）
  if [[ -n "${MATRIX_HOMESERVER:-}" && -n "${MATRIX_USER_ID:-}" && -n "${MATRIX_ACCESS_TOKEN:-}" ]]; then
    channels="${channels}\"matrix\":{\"homeserverUrl\":\"${MATRIX_HOMESERVER}\",\"userId\":\"${MATRIX_USER_ID}\",\"accessToken\":\"${MATRIX_ACCESS_TOKEN}\"},"
    ACTIVE_CHANNELS="${ACTIVE_CHANNELS}  ✅ Matrix\n"
  elif [[ -n "${MATRIX_HOMESERVER:-}" ]]; then
    echo "[PocketClaw] ⚠ Matrix 需要同时配置 MATRIX_HOMESERVER、MATRIX_USER_ID 和 MATRIX_ACCESS_TOKEN"
  fi

  _add_dual_channel "bluebubbles" "BLUEBUBBLES_SERVER_URL" "serverUrl" "BLUEBUBBLES_PASSWORD" "password" "BlueBubbles (iMessage)"
  _add_simple_channel "zalo" "ZALO_OA_ACCESS_TOKEN" "oaAccessToken" "Zalo"

  # 构建完整 channels JSON
  if [[ -n "$channels" ]]; then
    CHANNELS_BLOCK="\"channels\": {${channels%,}},"
  else
    CHANNELS_BLOCK=""
    ACTIVE_CHANNELS="  （无额外频道，仅 WebChat）\n"
  fi
}

# ────────────────────────────────────────────────
# generate_config: 生成 openclaw.json
# 安全说明：
#   allowedOrigins: "*" — 必须保留通配符（Docker 无法获取宿主机 LAN IP）
#   allowInsecureAuth: true — LAN 为 HTTP（非 HTTPS）环境
#   dangerouslyDisableDeviceAuth: true — 禁用设备审批（即插即用设计）
#   安全依赖: 随机 Gateway Token + 局域网物理隔离
# ────────────────────────────────────────────────
generate_config() {
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
    "port": $GATEWAY_PORT,
    "bind": "lan",
    "mode": "local",
    "controlUi": {
      "allowedOrigins": ["http://127.0.0.1:$GATEWAY_PORT", "http://localhost:$GATEWAY_PORT", "*"],
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

  # 如果没有频道配置，移除 heredoc 产生的多余空行
  if [[ -z "$CHANNELS_BLOCK" ]]; then
    sed -i.bak '/^  $/d' "$CONFIG_FILE" && rm -f "$CONFIG_FILE.bak"
  fi

  # 将 token 写入 workspace 供 AI 读取
  echo "$AUTH_PASS" > "$CONFIG_DIR/workspace/.gateway_token"

  # 写入 API 状态 JSON 供 mobile.html 读取
  cat > "/home/node/.openclaw/api-status.json" << STATUSEOF
{"provider":"$PROVIDER","model":"$MODEL_ID","label":"$PROVIDER_LABEL"}
STATUSEOF
}

# ────────────────────────────────────────────────
# print_banner: 打印启动配置摘要
# ────────────────────────────────────────────────
print_banner() {
  echo "============================================"
  echo "  PocketClaw 启动配置"
  echo "============================================"
  echo "  提供商: $PROVIDER_LABEL"
  echo "  模型:   $MODEL_ID"
  echo "  API:    $BASE_URL"
  echo "  端口:   $GATEWAY_PORT"
  echo "--------------------------------------------"
  echo "  聊天频道:"
  echo "  ✅ WebChat (内置)"
  printf "$ACTIVE_CHANNELS"
  echo "============================================"
}

# ────────────────────────────────────────────────
# find_control_ui: 定位 OpenClaw control-ui 目录
# 设置 CONTROL_UI_DIR
# ────────────────────────────────────────────────
find_control_ui() {
  local index_html
  index_html=$(find /usr/local/lib/node_modules/openclaw -name index.html -path '*/control-ui/*' 2>/dev/null | head -1)
  if [[ -n "$index_html" ]]; then
    CONTROL_UI_DIR="$(dirname "$index_html")"
  else
    CONTROL_UI_DIR=""
  fi
}

# ────────────────────────────────────────────────
# inject_mobile: 注入自定义页面到 OpenClaw 前端
# ────────────────────────────────────────────────
inject_mobile() {
  if [[ -z "$CONTROL_UI_DIR" || ! -d "$CONTROL_UI_DIR" ]]; then
    echo "  ⚠️  未找到 control-ui 目录，跳过 UI 自定义"
    return
  fi

  if [ -f "$CONTROL_UI_DIR/mobile.html" ]; then
    # 构建时已由 Dockerfile COPY 到位，read_only 容器无需运行时复制
    echo "  ✅ 手机专属页面已就绪"
  elif [ -f "$MOBILE_HTML" ]; then
    cp "$MOBILE_HTML" "$CONTROL_UI_DIR/mobile.html" 2>/dev/null && \
      echo "  ✅ 手机专属页面已注入" || echo "  ⚠️  手机页面注入失败（read_only 模式下可忽略）"
  fi
}

# ────────────────────────────────────────────────
# patch_gateway: 注入自定义文件路由到 Gateway
# 绕过 canvasHost SPA 拦截，使 mobile.html 可直接访问
# ────────────────────────────────────────────────
patch_gateway() {
  if [[ -z "$CONTROL_UI_DIR" || ! -d "$CONTROL_UI_DIR" ]]; then
    return
  fi

  local gw_dir
  gw_dir="$(dirname "$CONTROL_UI_DIR")"
  export CONTROL_UI_DIR GW_DIR="$gw_dir"

  if [ -f "$GATEWAY_PATCH" ]; then
    python3 "$GATEWAY_PATCH" 2>&1 || echo "  ⚠️  Gateway 路由注入脚本出错"
  else
    echo "  ⚠️  gateway-patch.py 不存在，跳过路由注入"
  fi
}

# ════════════════════════════════════════════════
# main: 入口函数
# ════════════════════════════════════════════════
main() {
  load_config
  load_provider
  build_channels
  generate_config
  print_banner
  find_control_ui
  inject_mobile
  patch_gateway

  # 启动 OpenClaw Gateway
  exec openclaw gateway --port "$GATEWAY_PORT" --verbose
}

# ── 执行 ──
main "$@"