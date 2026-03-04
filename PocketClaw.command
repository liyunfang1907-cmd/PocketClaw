#!/usr/bin/env bash
# ============================================================
# PocketClaw.command — macOS 统一控制面板
# 双击此文件即可在 macOS 上使用
# ============================================================
set -uo pipefail

# ── 定位项目 ──
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_PATH"
ENC_FILE="$PROJECT_DIR/secrets/.env.encrypted"
ENV_FILE="$PROJECT_DIR/.env"

# ── 公共函数库 ──
source "$SCRIPT_PATH/scripts/_common.sh"

# ── 颜色 ──
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

# (secure_wipe 已在 _common.sh 中定义)

# ── 检查状态（docker 命令加 5 秒超时，防止 Docker 启动中挂死）──
show_status() {
    if ! command -v docker &>/dev/null; then
        echo -e "  ${YELLOW}[状态] Docker 未安装${RESET}"
        return
    fi
    # 超时检测 Docker 是否就绪
    local docker_ready=false
    ( docker info >/dev/null 2>&1 ) &
    local pid=$!
    for _i in 1 2 3 4 5; do
        if ! kill -0 "$pid" 2>/dev/null; then
            wait "$pid" 2>/dev/null && docker_ready=true
            break
        fi
        sleep 1
    done
    if ! $docker_ready; then
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        echo -e "  ${YELLOW}[状态] Docker 正在启动中…${RESET}"
        return
    fi
    local status
    status=$(docker ps --filter "name=pocketclaw" --format "{{.Status}}" 2>/dev/null)
    if [ -n "$status" ]; then
        echo -e "  ${GREEN}[状态] PocketClaw 运行中${RESET}"
        # 读取实际的 Gateway Token（每次启动随机生成）
        local token=""
        if [ -f "$PROJECT_DIR/config/workspace/.gateway_token" ]; then
            token=$(cat "$PROJECT_DIR/config/workspace/.gateway_token" 2>/dev/null | tr -d '\n\r')
        fi
        if [ -n "$token" ]; then
            echo -e "  ${CYAN}[地址] http://127.0.0.1:18789/#token=${token}${RESET}"
        else
            echo -e "  ${CYAN}[地址] http://127.0.0.1:18789/${RESET}"
            echo -e "  ${YELLOW}[提示] Token 未知，请通过菜单 [1] 重新启动获取${RESET}"
        fi
    else
        echo -e "  [状态] PocketClaw 未运行"
    fi

    if [ -f "$ENC_FILE" ]; then
        echo -e "  ${GREEN}[加密] 已配置${RESET}"
    else
        echo -e "  ${YELLOW}[加密] 未配置（需要首次设置）${RESET}"
    fi
}

# ============================================================
#  主菜单
# ============================================================
show_menu() {
    clear
    echo ""
    echo -e "  ${BOLD}============================================${RESET}"
    echo -e "       ${BOLD}PocketClaw AI 助手 - 控制面板${RESET}"
    echo -e "       ${CYAN}macOS / Linux 版${RESET}"
    echo -e "  ${BOLD}============================================${RESET}"
    echo ""
    show_status
    echo ""
    echo "  --------------------------------------------"
    echo ""
    echo "    [1]  启动 PocketClaw"
    echo "    [2]  停止 PocketClaw（拔U盘前必须先停止）"
    echo "    [3]  打开聊天页面"
    echo "    [4]  切换模型/API Key"
    echo "    [5]  备份数据"
    echo "    [6]  查看日志"
    echo ""
    echo "    [0]  退出"
    echo ""
    echo "  --------------------------------------------"
}

# ============================================================
#  启动 — 委托给 scripts/start.sh
# ============================================================
do_start() {
    clear
    bash "$PROJECT_DIR/scripts/start.sh"
    echo ""
    read -rp "  按回车返回菜单..." _
}

# ============================================================
#  停止 — 委托给 scripts/stop.sh
# ============================================================
do_stop() {
    clear
    bash "$PROJECT_DIR/scripts/stop.sh"
}

# ============================================================
#  打开浏览器
# ============================================================
do_open() {
    # 读取实际的 Gateway Token
    local token=""
    if [ -f "$PROJECT_DIR/config/workspace/.gateway_token" ]; then
        token=$(cat "$PROJECT_DIR/config/workspace/.gateway_token" 2>/dev/null | tr -d '\n\r')
    fi
    local url="http://127.0.0.1:18789/#token=${token:-pocketclaw}"
    open "$url" 2>/dev/null || xdg-open "$url" 2>/dev/null || true
    sleep 1
}

# ============================================================
#  配置 / 加密 / 备份 / 日志 / API Key
# ============================================================
do_change_api() {
    echo ""
    bash "$PROJECT_DIR/scripts/change-api.sh"
    echo ""
    read -rp "  按回车返回菜单..." _
}

do_backup() {
    echo ""
    bash "$PROJECT_DIR/scripts/backup.sh"
    echo ""
    read -rp "  按回车返回菜单..." _
}

# U6: 日志查看
do_logs() {
    clear
    echo ""
    echo -e "  ${BOLD}── PocketClaw 日志 ──${RESET}"
    echo ""
    if command -v docker &>/dev/null && docker ps --filter "name=pocketclaw" --format "{{.Status}}" 2>/dev/null | grep -qi "up"; then
        echo -e "  ${CYAN}[容器运行日志 - 最后 50 行]${RESET}"
        echo "  ────────────────────────────────────────"
        docker logs pocketclaw --tail 50 2>&1
    else
        echo -e "  ${YELLOW}容器未运行，显示构建日志${RESET}"
    fi
    if [ -f "$PROJECT_DIR/data/logs/build.log" ]; then
        echo ""
        echo -e "  ${CYAN}[构建日志 - 最后 30 行]${RESET}"
        echo "  ────────────────────────────────────────"
        tail -30 "$PROJECT_DIR/data/logs/build.log"
    fi
    echo ""
    read -rp "  按回车返回菜单..." _
}

# ============================================================
#  主循环
# ============================================================
while true; do
    show_menu
    read -rp "  请选择 [0-6]: " CHOICE
    case "$CHOICE" in
        1) do_start ;;
        2) do_stop ;;
        3) do_open ;;
        4) do_change_api ;;
        5) do_backup ;;
        6) do_logs ;;
        0) echo ""; echo "  再见！"; exit 0 ;;
        *) echo "  无效选择"; sleep 1 ;;
    esac
done
