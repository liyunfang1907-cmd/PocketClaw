#!/usr/bin/env bash
# ============================================================
# change-api.sh  —— 切换 AI 模型提供商 / 更新 API Key (macOS/Linux)
# 支持: 智谱/DeepSeek/OpenAI/Claude/Gemini/Grok/Moonshot/通义千问/零一万物/硅基流动
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$PROJECT_DIR/.env"
ENC_FILE="$PROJECT_DIR/secrets/.env.encrypted"
PROVIDER_FILE="$PROJECT_DIR/config/workspace/.provider"
BOUND_FILE="$PROJECT_DIR/config/workspace/.bound_providers"
NEED_REENCRYPT=0
MASTER_PASS=""

trap 'unset MASTER_PASS 2>/dev/null' EXIT

echo ""
echo "==================================================="
echo "      PocketClaw 模型切换工具"
echo "==================================================="
echo ""
echo "  选择 AI 模型提供商:"
echo ""
echo "  [1] iFlow 心流        (推荐，免费多模型聚合)"
echo "      DeepSeek V3.2 / Qwen3 / Kimi K2 等顶级模型，均免费"
echo "      注册: https://platform.iflow.cn"
echo ""
echo "  [2] 智谱 AI          (免费)"
echo "      GLM-4.7-Flash / GLM-4.6V-Flash / GLM-Z1-Flash"
echo "      注册: https://open.bigmodel.cn"
echo ""
echo "  [3] DeepSeek          (性价比最高)"
echo "      DeepSeek-V3 / DeepSeek-R1"
echo "      注册: https://platform.deepseek.com"
echo ""
echo "  [4] Moonshot/Kimi     (长文本能力强)"
echo "      Moonshot-v1 (8K/32K/128K)"
echo "      注册: https://platform.moonshot.cn"
echo ""
echo "  [5] 通义千问 Qwen     (阿里云)"
echo "      Qwen-Turbo / Qwen-Plus / Qwen-Max"
echo "      注册: https://dashscope.console.aliyun.com"
echo ""
echo "  [6] 零一万物 Yi       (性能优秀)"
echo "      Yi-Lightning / Yi-Large"
echo "      注册: https://platform.lingyiwanwu.com"
echo ""
echo "  [7] 硅基流动          (免费开源模型聚合)"
echo "      DeepSeek V3/R1 / Qwen / GLM (均免费)"
echo "      注册: https://cloud.siliconflow.cn"
echo ""
echo "  [8] 智谱 AI (付费高级) GLM-4-Plus / GLM-4-Long"
echo "      注册: https://open.bigmodel.cn"
echo ""
echo "  [9] OpenAI             GPT-4o / GPT-4.1 / o3-mini"
echo "      注册: https://platform.openai.com"
echo ""
echo " [10] Anthropic Claude   Claude Sonnet 4 / Opus 4"
echo "      注册: https://console.anthropic.com"
echo ""
echo " [11] Google Gemini      Gemini 2.5 Flash / Pro"
echo "      注册: https://aistudio.google.com"
echo ""
echo " [12] xAI Grok           Grok 3 / Grok 3 Mini"
echo "      注册: https://console.x.ai"
echo ""
echo "  [0] 仅更新当前 API Key (不切换提供商)"
echo ""
read -rp "请选择 [0-12]: " MENU_CHOICE

# ── 解密 .env 的公共函数 ──
do_decrypt() {
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENC_FILE" ]; then
            echo "[信息] 正在解密 .env ..."
            read -s -p "  Master Password: " MASTER_PASS
            echo ""
            if [ -z "$MASTER_PASS" ]; then
                echo "[错误] 密码不能为空。"
                exit 1
            fi
            if ! decrypt_env_file "$ENC_FILE" "$ENV_FILE" "$MASTER_PASS"; then
                echo "[错误] 解密失败，密码可能不正确。"
                rm -f "$ENV_FILE"
                exit 1
            fi
            NEED_REENCRYPT=1
            echo "[OK] 解密成功"
        else
            echo "[错误] 未找到 .env 或 .env.encrypted"
            echo "请先运行 setup-env.sh"
            exit 1
        fi
    fi
}

# ── 重新加密 + 擦除 ──
do_reencrypt_and_cleanup() {
    if [ "$NEED_REENCRYPT" -eq 1 ]; then
        echo ""
        echo "[信息] 重新加密 .env ..."
        if encrypt_env_file "$ENV_FILE" "$ENC_FILE" "$MASTER_PASS"; then
            echo "[OK] 已重新加密"
        else
            echo "[错误] 重新加密失败！明文 .env 已保留，请手动处理。"
            return
        fi
        secure_wipe "$ENV_FILE"
        echo "[安全] 已安全擦除明文 .env"
    fi
}

# ── [0] 仅更新 API Key ──
if [ "$MENU_CHOICE" = "0" ]; then
    do_decrypt
    CUR_KEY=$(grep -i "^ZHIPU_API_KEY=\|^OPENAI_API_KEY=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-)
    echo ""
    if [ -n "$CUR_KEY" ]; then
        echo "  当前 API Key: ${CUR_KEY:0:8}****"
    fi
    echo ""
    read -rp "  新的 API Key (留空保持不变): " NEW_KEY
    if [ -z "$NEW_KEY" ]; then
        echo "  未修改。"
    else
        sed_inplace "s|^ZHIPU_API_KEY=.*|OPENAI_API_KEY=$NEW_KEY|" "$ENV_FILE"
        sed_inplace "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=$NEW_KEY|" "$ENV_FILE"
        # 同步 .provider 文件
        if [ -f "$PROVIDER_FILE" ]; then
            sed_inplace "s|^API_KEY=.*|API_KEY=$NEW_KEY|" "$PROVIDER_FILE"
            echo "  [OK] Provider 配置已同步"
        fi
        echo "  [OK] API Key 已更新"
    fi
    do_reencrypt_and_cleanup
    echo ""
    echo "[完成] API Key 更换完成！"
    exit 0
fi

# ── [1-6] 切换提供商 ──
case "$MENU_CHOICE" in
    1) PROV="iflow";       PROV_NAME="iFlow 心流";            DEFAULT_MODEL="deepseek-v3.2";           KEY_URL="https://platform.iflow.cn" ;;
    2) PROV="zhipu";       PROV_NAME="智谱 AI";             DEFAULT_MODEL="glm-4.7-flash";            KEY_URL="https://open.bigmodel.cn/usercenter/apikeys" ;;
    3) PROV="deepseek";    PROV_NAME="DeepSeek";             DEFAULT_MODEL="deepseek-chat";             KEY_URL="https://platform.deepseek.com/api_keys" ;;
    4) PROV="moonshot";    PROV_NAME="Moonshot/Kimi";        DEFAULT_MODEL="moonshot-v1-auto";          KEY_URL="https://platform.moonshot.cn/console/api-keys" ;;
    5) PROV="qwen";        PROV_NAME="通义千问 Qwen";         DEFAULT_MODEL="qwen-turbo-latest";         KEY_URL="https://dashscope.console.aliyun.com/apiKey" ;;
    6) PROV="yi";          PROV_NAME="零一万物 Yi";            DEFAULT_MODEL="yi-lightning";              KEY_URL="https://platform.lingyiwanwu.com/apikeys" ;;
    7) PROV="siliconflow"; PROV_NAME="硅基流动 SiliconFlow";   DEFAULT_MODEL="deepseek-ai/DeepSeek-V3";  KEY_URL="https://cloud.siliconflow.cn/account/ak" ;;
    8) PROV="zhipu-pro";   PROV_NAME="智谱 AI (付费高级)";   DEFAULT_MODEL="glm-4-plus";              KEY_URL="https://open.bigmodel.cn/usercenter/apikeys" ;;
    9) PROV="openai";      PROV_NAME="OpenAI";               DEFAULT_MODEL="gpt-4o";                  KEY_URL="https://platform.openai.com/api-keys" ;;
   10) PROV="anthropic";   PROV_NAME="Anthropic Claude";     DEFAULT_MODEL="claude-sonnet-4-20250514"; KEY_URL="https://console.anthropic.com/settings/keys" ;;
   11) PROV="gemini";      PROV_NAME="Google Gemini";        DEFAULT_MODEL="gemini-2.5-flash";        KEY_URL="https://aistudio.google.com/apikey" ;;
   12) PROV="xai";         PROV_NAME="xAI Grok";             DEFAULT_MODEL="grok-3-mini";             KEY_URL="https://console.x.ai" ;;
    *) echo "  无效选择"; exit 1 ;;
esac

echo ""
echo "  已选择: $PROV_NAME"
echo "  获取 API Key: $KEY_URL"

if [ "$PROV" = "iflow" ]; then
    echo ""
    echo "  获取 API Key 步骤:"
    echo "  1. 打开 https://platform.iflow.cn"
    echo "  2. 注册/登录后, 点击「API Key 管理」"
    echo "  3. 点击「重置 API 密钥」, 复制生成的 Key"
    echo ""
    echo "  [!] 注意: API Key 有效期只有 7 天"
    echo "      到期后需再次点击「重置 API 密钥」获取新Key"
    echo "      并通过「切换 API」重新输入到 PocketClaw"
fi
echo ""

read -rp "  请粘贴你的 ${PROV_NAME} API Key: " NEW_KEY
if [ -z "$NEW_KEY" ]; then
    echo "  [错误] API Key 不能为空。"
    exit 1
fi

echo ""
echo "[信息] 正在保存配置..."

# 写入 .provider 文件
cat > "$PROVIDER_FILE" << EOF
# PocketClaw Provider Config
PROVIDER_NAME=$PROV
API_KEY=$NEW_KEY
MODEL_ID=$DEFAULT_MODEL
EOF
echo "  [OK] 提供商配置已保存"

# 记录已绑定的提供商
grep -qxF "$PROV" "$BOUND_FILE" 2>/dev/null || echo "$PROV" >> "$BOUND_FILE"

# 更新 .env
do_decrypt
if [ -f "$ENV_FILE" ]; then
    sed_inplace "s|^ZHIPU_API_KEY=.*|OPENAI_API_KEY=$NEW_KEY|" "$ENV_FILE"
    sed_inplace "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=$NEW_KEY|" "$ENV_FILE"
    sed_inplace "s|^PROVIDER_NAME=.*|PROVIDER_NAME=$PROV|" "$ENV_FILE"
    sed_inplace "s|^OPENCLAW_MODEL=.*|OPENCLAW_MODEL=$DEFAULT_MODEL|" "$ENV_FILE"
else
    cat > "$ENV_FILE" << EOF
COMPOSE_PROJECT_NAME=pocketclaw
PROVIDER_NAME=$PROV
OPENCLAW_MODEL=$DEFAULT_MODEL
OPENAI_API_KEY=$NEW_KEY
GATEWAY_AUTH_PASSWORD=pocketclaw
EOF
fi
echo "  [OK] .env 已更新"

do_reencrypt_and_cleanup

# 重启提示
echo ""
read -rp "是否重启 PocketClaw 使更改生效？(y/N): " RESTART
if [[ "$RESTART" =~ ^[Yy]$ ]]; then
    echo "[信息] 正在重启 PocketClaw..."
    if ! run_compose -f "$PROJECT_DIR/docker-compose.yml" restart pocketclaw 2>/dev/null; then
        echo "[信息] 尝试完全重建..."
        run_compose -f "$PROJECT_DIR/docker-compose.yml" up -d --build 2>/dev/null
    fi
    echo "[OK] 重启完成！"
    echo ""
    echo "  当前提供商: $PROV_NAME"
    echo "  当前模型:   $DEFAULT_MODEL"
    # 读取实际 Gateway Token
    _token=""
    if [ -f "$PROJECT_DIR/config/workspace/.gateway_token" ]; then
        _token=$(cat "$PROJECT_DIR/config/workspace/.gateway_token" 2>/dev/null | tr -d '\n\r')
    fi
    echo "  控制面板:   http://127.0.0.1:18789/#token=${_token:-pocketclaw}"
else
    echo ""
    echo "[提示] 稍后手动重启: docker compose restart"
fi

echo ""
echo "[完成] 模型切换完成！"
