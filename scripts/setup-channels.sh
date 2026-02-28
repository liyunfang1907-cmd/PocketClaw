#!/usr/bin/env bash
# ============================================================
# setup-channels.sh  —— 聊天频道配置向导
# 用法: bash scripts/setup-channels.sh
# 支持频道: Telegram / Discord / Slack / WhatsApp / Signal
#           Google Chat / Microsoft Teams / Matrix / BlueBubbles / Zalo
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
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

# --------------- 检查 .env 是否存在 ---------------
if [ ! -f "$ENV_FILE" ]; then
    # 尝试解密
    if [ -f "$PROJECT_DIR/secrets/.env.encrypted" ]; then
        yellow "[提示] 需要先解密 .env 文件"
        if [ -f "$SCRIPT_DIR/decrypt-secrets.sh" ]; then
            bash "$SCRIPT_DIR/decrypt-secrets.sh" || {
                red "[错误] 解密失败，请先运行 setup-env.sh 完成基础配置"
                exit 1
            }
        fi
    else
        red "[错误] 未找到 .env 文件，请先运行 setup-env.sh 完成基础配置"
        exit 1
    fi
fi

# --------------- 追加函数 ---------------
append_env() {
    local key="$1" value="$2" comment="${3:-}"
    # 检查是否已存在，如果存在则更新
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        # macOS 和 Linux 兼容的 sed
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
        else
            sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
        fi
    else
        if [ -n "$comment" ]; then
            echo "" >> "$ENV_FILE"
            echo "# $comment" >> "$ENV_FILE"
        fi
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

echo ""
cyan "╔══════════════════════════════════════════════════════╗"
cyan "║         PocketClaw 聊天频道配置向导                ║"
cyan "║   除了默认的 WebChat，你还可以接入更多聊天软件     ║"
cyan "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  PocketClaw 默认已启用 WebChat（浏览器聊天界面）。"
echo "  以下频道均为 可选 配置，按需启用即可。"
echo ""
cyan "  ┌────────────────────────────────────────────┐"
cyan "  │  可选频道:                                 │"
echo "  │                                            │"
echo "  │  1. Telegram    — 最简单，推荐首选         │"
echo "  │  2. Discord     — 游戏/社区用户推荐        │"
echo "  │  3. Slack       — 办公场景推荐             │"
echo "  │  4. WhatsApp    — 海外用户推荐             │"
echo "  │  5. Signal      — 隐私优先推荐             │"
echo "  │  6. Google Chat — Google 生态用户          │"
echo "  │  7. MS Teams    — 企业办公推荐             │"
echo "  │  8. Matrix      — 开源去中心化聊天         │"
echo "  │  9. BlueBubbles — iMessage (需 macOS)      │"
echo "  │ 10. Zalo        — 越南市场                 │"
echo "  │                                            │"
echo "  │  0. 跳过，不配置额外频道                   │"
cyan "  └────────────────────────────────────────────┘"
echo ""

read -rp "  请输入要配置的频道编号（多个用逗号分隔，如 1,2）: " CHANNEL_INPUT

if [[ "$CHANNEL_INPUT" == "0" || -z "$CHANNEL_INPUT" ]]; then
    green "  已跳过频道配置，仅使用 WebChat。"
    echo ""
    exit 0
fi

IFS=',' read -ra SELECTED <<< "$CHANNEL_INPUT"
CONFIGURED=0

for ch in "${SELECTED[@]}"; do
    ch=$(echo "$ch" | xargs)  # 去除空格
    case "$ch" in
        1)
            echo ""
            cyan "── 配置 Telegram ──"
            echo "  你需要一个 Telegram Bot Token。"
            echo "  获取方法: 在 Telegram 中搜索 @BotFather → /newbot → 按提示创建"
            echo ""
            read -rp "  请粘贴你的 Bot Token: " TG_TOKEN
            if [ -n "$TG_TOKEN" ]; then
                append_env "TELEGRAM_BOT_TOKEN" "$TG_TOKEN" "Telegram Bot Token"
                green "  ✓ Telegram 已配置"
                ((CONFIGURED++))
            else
                yellow "  已跳过 Telegram"
            fi
            ;;
        2)
            echo ""
            cyan "── 配置 Discord ──"
            echo "  你需要一个 Discord Bot Token。"
            echo "  获取方法: https://discord.com/developers/applications"
            echo "  创建应用 → Bot → Reset Token → 复制"
            echo ""
            read -rp "  请粘贴你的 Bot Token: " DC_TOKEN
            if [ -n "$DC_TOKEN" ]; then
                append_env "DISCORD_BOT_TOKEN" "$DC_TOKEN" "Discord Bot Token"
                green "  ✓ Discord 已配置"
                ((CONFIGURED++))
            else
                yellow "  已跳过 Discord"
            fi
            ;;
        3)
            echo ""
            cyan "── 配置 Slack ──"
            echo "  你需要 Slack Bot Token 和 App Token。"
            echo "  获取方法: https://api.slack.com/apps → 创建应用"
            echo "  Bot Token (xoxb-...) 在 OAuth & Permissions 页面"
            echo "  App Token (xapp-...) 在 Basic Information → App-Level Tokens"
            echo ""
            read -rp "  请粘贴 Bot Token (xoxb-...): " SLACK_BOT
            read -rp "  请粘贴 App Token (xapp-...): " SLACK_APP
            if [ -n "$SLACK_BOT" ] && [ -n "$SLACK_APP" ]; then
                append_env "SLACK_BOT_TOKEN" "$SLACK_BOT" "Slack Bot Token"
                append_env "SLACK_APP_TOKEN" "$SLACK_APP"
                green "  ✓ Slack 已配置"
                ((CONFIGURED++))
            else
                yellow "  已跳过 Slack（需要同时填写两个 Token）"
            fi
            ;;
        4)
            echo ""
            cyan "── 配置 WhatsApp ──"
            echo "  WhatsApp 使用 Baileys 协议，需要扫码链接设备。"
            echo "  首次启动后在容器日志中会显示二维码，用 WhatsApp 扫描即可。"
            echo "  这里只需填写允许与 AI 对话的手机号码。"
            echo ""
            read -rp "  请输入允许的手机号（含国际区号，多个用逗号分隔，如 +8613800138000）: " WA_NUMS
            if [ -n "$WA_NUMS" ]; then
                append_env "WHATSAPP_ALLOW_FROM" "$WA_NUMS" "WhatsApp 允许列表"
                green "  ✓ WhatsApp 已配置"
                yellow "  ⚠ 首次启动时请查看日志扫码: docker compose logs -f pocketclaw"
                ((CONFIGURED++))
            else
                yellow "  已跳过 WhatsApp"
            fi
            ;;
        5)
            echo ""
            cyan "── 配置 Signal ──"
            echo "  Signal 需要安装 signal-cli 并注册号码。"
            echo "  详见: https://docs.openclaw.ai/channels/signal"
            echo ""
            read -rp "  请输入 Signal 注册手机号（如 +8613800138000）: " SIG_NUM
            if [ -n "$SIG_NUM" ]; then
                append_env "SIGNAL_PHONE_NUMBER" "$SIG_NUM" "Signal 手机号"
                green "  ✓ Signal 已配置"
                yellow "  ⚠ 还需要在容器内配置 signal-cli，详见文档"
                ((CONFIGURED++))
            else
                yellow "  已跳过 Signal"
            fi
            ;;
        6)
            echo ""
            cyan "── 配置 Google Chat ──"
            echo "  需要 Google Cloud 项目的服务账号密钥文件。"
            echo "  详见: https://docs.openclaw.ai/channels/googlechat"
            echo ""
            read -rp "  服务账号 JSON 密钥文件路径: " GC_CRED
            if [ -n "$GC_CRED" ]; then
                append_env "GOOGLE_CHAT_CREDENTIALS" "$GC_CRED" "Google Chat 服务账号密钥"
                read -rp "  Chat Space ID（可选，回车跳过）: " GC_SPACE
                if [ -n "$GC_SPACE" ]; then
                    append_env "GOOGLE_CHAT_SPACES" "$GC_SPACE"
                fi
                green "  ✓ Google Chat 已配置"
                ((CONFIGURED++))
            else
                yellow "  已跳过 Google Chat"
            fi
            ;;
        7)
            echo ""
            cyan "── 配置 Microsoft Teams ──"
            echo "  需要 Azure Bot Framework 的 App ID 和 App Password。"
            echo "  详见: https://docs.openclaw.ai/channels/msteams"
            echo ""
            read -rp "  App ID: " MS_ID
            read -rp "  App Password: " MS_PASS
            if [ -n "$MS_ID" ] && [ -n "$MS_PASS" ]; then
                append_env "MSTEAMS_APP_ID" "$MS_ID" "Microsoft Teams"
                append_env "MSTEAMS_APP_PASSWORD" "$MS_PASS"
                green "  ✓ Microsoft Teams 已配置"
                ((CONFIGURED++))
            else
                yellow "  已跳过 Microsoft Teams（需要同时填写 ID 和 Password）"
            fi
            ;;
        8)
            echo ""
            cyan "── 配置 Matrix ──"
            echo "  你需要 Matrix Homeserver URL、User ID 和 Access Token。"
            echo "  可以使用 matrix.org 或自建服务器。"
            echo ""
            read -rp "  Homeserver URL (如 https://matrix.org): " MX_HOME
            read -rp "  User ID (如 @mybot:matrix.org): " MX_USER
            read -rp "  Access Token: " MX_TOKEN
            if [ -n "$MX_HOME" ] && [ -n "$MX_USER" ] && [ -n "$MX_TOKEN" ]; then
                append_env "MATRIX_HOMESERVER" "$MX_HOME" "Matrix"
                append_env "MATRIX_USER_ID" "$MX_USER"
                append_env "MATRIX_ACCESS_TOKEN" "$MX_TOKEN"
                green "  ✓ Matrix 已配置"
                ((CONFIGURED++))
            else
                yellow "  已跳过 Matrix（需要填写全部三项）"
            fi
            ;;
        9)
            echo ""
            cyan "── 配置 BlueBubbles (iMessage) ──"
            echo "  需要在 macOS 上运行 BlueBubbles Server。"
            echo "  详见: https://docs.openclaw.ai/channels/bluebubbles"
            echo ""
            read -rp "  BlueBubbles Server URL (如 http://192.168.1.100:1234): " BB_URL
            read -rp "  Server Password: " BB_PASS
            if [ -n "$BB_URL" ] && [ -n "$BB_PASS" ]; then
                append_env "BLUEBUBBLES_SERVER_URL" "$BB_URL" "BlueBubbles (iMessage)"
                append_env "BLUEBUBBLES_PASSWORD" "$BB_PASS"
                green "  ✓ BlueBubbles 已配置"
                ((CONFIGURED++))
            else
                yellow "  已跳过 BlueBubbles（需要同时填写 URL 和 Password）"
            fi
            ;;
        10)
            echo ""
            cyan "── 配置 Zalo ──"
            echo "  需要 Zalo Official Account 的 Access Token。"
            echo "  详见: https://developers.zalo.me/"
            echo ""
            read -rp "  OA Access Token: " ZA_TOKEN
            if [ -n "$ZA_TOKEN" ]; then
                append_env "ZALO_OA_ACCESS_TOKEN" "$ZA_TOKEN" "Zalo Official Account"
                green "  ✓ Zalo 已配置"
                ((CONFIGURED++))
            else
                yellow "  已跳过 Zalo"
            fi
            ;;
        *)
            yellow "  未知选项: $ch，已跳过"
            ;;
    esac
done

echo ""
if [ "$CONFIGURED" -gt 0 ]; then
    green "╔══════════════════════════════════════════════════╗"
    green "║   ✓ 已配置 ${CONFIGURED} 个额外频道                       ║"
    green "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "  频道配置已写入 .env 文件。"
    echo "  重新加密 .env 以保护敏感信息..."
    echo ""

    # 重新加密
    ENCRYPT_SCRIPT="$SCRIPT_DIR/encrypt-secrets.sh"
    if [ -f "$ENCRYPT_SCRIPT" ]; then
        if bash "$ENCRYPT_SCRIPT"; then
            source "$SCRIPT_DIR/_common.sh" 2>/dev/null || true
            if type secure_wipe &>/dev/null; then
                secure_wipe "$PROJECT_DIR/.env"
            else
                rm -f "$PROJECT_DIR/.env"
            fi
            green "  ✓ .env 已重新加密保护"
        else
            yellow "  ⚠ 重新加密失败，请稍后手动运行 encrypt-secrets.sh"
        fi
    fi

    echo ""
    yellow "  ⚠ 需要重启 PocketClaw 才能生效:"
    echo "     bash scripts/stop.sh && bash scripts/start.sh"
else
    echo "  未配置任何频道，保持当前设置不变。"
fi
echo ""
