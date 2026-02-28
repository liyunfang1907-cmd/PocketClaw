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

# ── 生成 openclaw.json ──
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
  "browser": {
    "enabled": false
  }
}
JSONEOF

echo "============================================"
echo "  PocketClaw 启动配置"
echo "============================================"
echo "  提供商: $PROVIDER_LABEL"
echo "  模型:   $MODEL_ID"
echo "  API:    $BASE_URL"
echo "  端口:   18789"
echo "============================================"

# ── 启动 OpenClaw Gateway ──
exec openclaw gateway --port 18789 --verbose
