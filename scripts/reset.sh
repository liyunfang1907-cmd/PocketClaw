#!/usr/bin/env bash
# ============================================================
# reset.sh  —— 重置 PocketClaw 到初始状态 [macOS/Linux]
# 用法: bash scripts/reset.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
detect_project_dir

echo
echo "======================================"
echo "   PocketClaw 重置工具"
echo "======================================"
echo
echo "[警告] 此操作将:"
echo "  1. 停止并删除容器和镜像"
echo "  2. 删除 .env 明文和加密文件"
echo "  3. 删除会话数据和日志"
echo "  4. 删除下载的源代码"
echo
echo "  config/ 目录 (openclaw.json等) 将被保留."
echo "  scripts/ 目录 (脚本) 将被保留."
echo

read -rp "确定要重置吗? 输入 YES 确认: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "已取消。"
    exit 0
fi

echo

# --------------- 1. 停止容器 ---------------
echo "[1/5] 停止容器..."
cd "$PROJECT_DIR"
run_compose -f "$PROJECT_DIR/docker-compose.yml" down --rmi all --volumes 2>/dev/null || true
echo "  完成。"

# --------------- 2. 删除 .env ---------------
echo "[2/5] 清理敏感文件..."
secure_wipe "$PROJECT_DIR/.env"
rm -f "$PROJECT_DIR/secrets/.env.encrypted"
rm -f "$PROJECT_DIR/config/workspace/.provider"
echo "  完成。"

# --------------- 3. 删除数据 ---------------
echo "[3/5] 清理数据目录..."
for dir in sessions logs credentials; do
    if [ -d "$PROJECT_DIR/data/$dir" ]; then
        rm -rf "$PROJECT_DIR/data/${dir:?}"
        mkdir -p "$PROJECT_DIR/data/$dir"
    fi
done
echo "  完成。"

# --------------- 4. 删除源码 ---------------
echo "[4/5] 清理源代码..."
rm -rf "$PROJECT_DIR/openclaw-src"
echo "  完成。"

# --------------- 5. 保留文件清单 ---------------
echo "[5/5] 已保留的文件:"
echo "  config/openclaw.json"
echo "  config/workspace/AGENTS.md"
echo "  config/workspace/SOUL.md"
echo "  scripts/*.sh / *.bat"
echo "  docker-compose.yml"
echo "  .env.example"
echo "  README.md"

echo
echo "======================================"
echo "  重置完成!"
echo "======================================"
echo
echo "重新开始: bash scripts/setup-env.sh"
