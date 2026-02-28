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

# ── 检查状态 ──
show_status() {
    if ! command -v docker &>/dev/null; then
        echo -e "  ${YELLOW}[状态] Docker 未安装${RESET}"
        return
    fi
    if ! docker info &>/dev/null; then
        echo -e "  ${YELLOW}[状态] Docker 未运行${RESET}"
        return
    fi
    local status
    status=$(docker ps --filter "name=pocketclaw" --format "{{.Status}}" 2>/dev/null)
    if [ -n "$status" ]; then
        echo -e "  ${GREEN}[状态] PocketClaw 运行中 - $status${RESET}"
        echo -e "  ${CYAN}[地址] http://127.0.0.1:18789/pocketclaw${RESET}"
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
    echo "    [5]  查看状态 / 日志"
    echo "    [6]  备份数据"
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
    open "http://127.0.0.1:18789/pocketclaw" 2>/dev/null || xdg-open "http://127.0.0.1:18789/pocketclaw" 2>/dev/null || true
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

do_status() {
    echo ""
    echo -e "  ${BOLD}============================================${RESET}"
    echo -e "       ${BOLD}PocketClaw 状态${RESET}"
    echo -e "  ${BOLD}============================================${RESET}"
    echo ""
    docker ps --filter "name=pocketclaw" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  Docker 未运行"
    echo ""
    echo -e "  ${CYAN}[信息] 最近 30 行日志:${RESET}"
    echo ""
    docker logs pocketclaw --tail 30 2>/dev/null || echo "  容器未运行"
    echo ""
    read -rp "  按回车返回菜单..." _
}

do_backup() {
    echo ""
    bash "$PROJECT_DIR/scripts/backup.sh"
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
        5) do_status ;;
        6) do_backup ;;
        0) echo ""; echo "  再见！"; exit 0 ;;
        *) echo "  无效选择"; sleep 1 ;;
    esac
done
