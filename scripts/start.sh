#!/usr/bin/env bash
# ============================================================
# start.sh  —— PocketClaw 启动器 (macOS/Linux)
# 用法: bash scripts/start.sh
# ============================================================
set -euo pipefail

# ── 公共函数库 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── 无论正常退出还是异常退出，都清理密码变量 ──
trap 'unset MASTER_PASS 2>/dev/null' EXIT
ENC_FILE="$PROJECT_DIR/secrets/.env.encrypted"

echo "============================================"
echo "  PocketClaw 启动器 (macOS/Linux)"
echo "============================================"
echo ""
echo "[信息] 项目目录: $PROJECT_DIR"
echo ""

# ── 检查 Docker ──
if ! command -v docker &>/dev/null; then
    echo "[错误] 未检测到 Docker！"
    echo "       请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo "[信息] Docker 未运行，正在自动启动 Docker Desktop..."
    open -a "Docker" 2>/dev/null || true
    echo "       等待 Docker 引擎就绪（最多等待 120 秒）..."
    WAIT_COUNT=0
    while ! docker info &>/dev/null; do
        sleep 5
        WAIT_COUNT=$((WAIT_COUNT + 5))
        if [ "$WAIT_COUNT" -ge 120 ]; then
            echo "[错误] Docker Desktop 启动超时！请手动启动后重试。"
            exit 1
        fi
        echo "       已等待 ${WAIT_COUNT} 秒..."
    done
    echo "[OK] Docker Desktop 已自动启动"
fi

echo "[OK] Docker 已就绪"
echo ""

# ── 文件完整性校验 ──
if [ -f "$SCRIPT_DIR/.checksums.sha256" ]; then
    echo "[信息] 正在校验文件完整性..."
    TAMPERED=0
    while IFS='  ' read -r expected_hash filepath; do
        [ -z "$expected_hash" ] && continue
        if [ -f "$PROJECT_DIR/$filepath" ]; then
            actual_hash=$(shasum -a 256 "$PROJECT_DIR/$filepath" 2>/dev/null | awk '{print $1}')
            if [ "$actual_hash" != "$expected_hash" ]; then
                echo "  [警告] 文件已被修改: $filepath"
                TAMPERED=$((TAMPERED + 1))
            fi
        fi
    done < "$SCRIPT_DIR/.checksums.sha256"
    if [ "$TAMPERED" -gt 0 ]; then
        echo ""
        echo "[警告] 检测到 $TAMPERED 个文件被修改，修改后的版本不受原作者技术支持。"
        echo "       如非本人操作，请注意安全风险。"
        echo ""
    else
        echo "[OK] 文件完整性校验通过 ✓"
    fi
    echo ""
fi

# ── 检查 .env ──
if [ ! -f "$PROJECT_DIR/.env" ]; then
    if [ -f "$ENC_FILE" ]; then
        echo "[信息] 检测到加密配置，正在解密..."
        read -s -p "请输入 Master Password: " MASTER_PASS
        echo ""
        if [ -z "$MASTER_PASS" ]; then
            echo "[错误] 密码不能为空。"
            exit 1
        fi
        # 通过 stdin 传递密码，避免 -pass pass: 在进程列表 (ps aux) 中泄露
        if ! printf '%s' "$MASTER_PASS" | openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
            -in "$ENC_FILE" \
            -out "$PROJECT_DIR/.env" \
            -pass stdin 2>/dev/null; then
            echo "[错误] 解密失败，密码可能不正确。"
            rm -f "$PROJECT_DIR/.env"
            exit 1
        fi
        unset MASTER_PASS
        echo "[OK] 解密成功"
    else
        echo "[警告] 未找到 .env 配置文件！正在启动配置向导..."
        bash "$PROJECT_DIR/scripts/setup-env.sh" || true
        # setup-env.sh 加密后会删除明文 .env，此时需要走解密流程
        if [ ! -f "$PROJECT_DIR/.env" ]; then
            if [ -f "$ENC_FILE" ]; then
                echo ""
                echo "[信息] 配置已加密保存，现在需要解密以启动..."
                read -s -p "请输入 Master Password: " MASTER_PASS
                echo ""
                if [ -z "$MASTER_PASS" ]; then
                    echo "[错误] 密码不能为空。"
                    exit 1
                fi
                if ! printf '%s' "$MASTER_PASS" | openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
                    -in "$ENC_FILE" \
                    -out "$PROJECT_DIR/.env" \
                    -pass stdin 2>/dev/null; then
                    echo "[错误] 解密失败，密码可能不正确。"
                    rm -f "$PROJECT_DIR/.env"
                    exit 1
                fi
                unset MASTER_PASS
                echo "[OK] 解密成功"
            else
                echo "[错误] 配置未完成。"
                exit 1
            fi
        fi
    fi
fi

echo "[OK] 配置文件就绪"
echo ""

# ── 检查 Docker Hub 连通性 ──
echo "[信息] 检查 Docker Hub 连通性..."
if ! docker pull --quiet hello-world &>/dev/null; then
    echo ""
    echo "[信息] Docker Hub 不可达，正在自动配置国内镜像加速器..."
    DAEMON_JSON="$HOME/.docker/daemon.json"
    mkdir -p "$(dirname "$DAEMON_JSON")"
    if [ -f "$DAEMON_JSON" ]; then
        # 用 python3 (macOS 自带) 合并配置
        python3 -c "
import json, sys
try:
    cfg = json.load(open('$DAEMON_JSON'))
except: cfg = {}
cfg['registry-mirrors'] = ['https://docker.1ms.run','https://docker.xuanyuan.me']
json.dump(cfg, open('$DAEMON_JSON','w'), indent=2)
"
    else
        echo '{"registry-mirrors":["https://docker.1ms.run","https://docker.xuanyuan.me"]}' > "$DAEMON_JSON"
    fi
    echo "[OK] 镜像加速器已配置"
    echo "[信息] 正在重启 Docker Desktop 以应用配置..."
    osascript -e 'quit app "Docker"' 2>/dev/null || true
    sleep 3
    open -a "Docker"
    echo "       等待 Docker 引擎就绪（最多等待 120 秒）..."
    WAIT_COUNT2=0
    while ! docker info &>/dev/null; do
        sleep 5
        WAIT_COUNT2=$((WAIT_COUNT2 + 5))
        if [ "$WAIT_COUNT2" -ge 120 ]; then
            echo "[错误] Docker Desktop 重启超时！请手动重启后重试。"
            exit 1
        fi
        echo "       已等待 ${WAIT_COUNT2} 秒..."
    done
    echo "[OK] Docker 已重启，镜像加速器已生效"
else
    echo "[OK] Docker Hub 连接正常"
    docker rmi hello-world &>/dev/null
fi

# ── 启动 ──
echo ""
echo "┌──────────────────────────────────────────┐"
echo "│  首次构建大约需要 2-5 分钟               │"
echo "│  请耐心等待，不要关闭此窗口              │"
echo "│                                          │"
echo "│  构建日志: data/logs/build.log            │"
echo "└──────────────────────────────────────────┘"
echo ""
echo "[..] 构建中，请稍候..."

mkdir -p "$PROJECT_DIR/data/logs"
BUILD_LOG="$PROJECT_DIR/data/logs/build.log"

BUILD_OK=0
run_compose -f "$PROJECT_DIR/docker-compose.yml" up -d --build > "$BUILD_LOG" 2>&1 || BUILD_OK=1

if [ "$BUILD_OK" -ne 0 ]; then
    echo ""
    echo "[错误] 容器启动失败！"
    echo "  构建日志: $BUILD_LOG"
    echo "  可能原因:"
    echo "  1. Docker Hub 无法访问 → 请配置镜像加速器"
    echo "  2. 端口 18789 被占用 → 关闭占用该端口的程序"
    echo "  3. 磁盘空间不足 → docker system prune"
    exit 1
fi
echo "[OK] 构建完成！"

echo ""
echo "============================================"
echo "  [OK] PocketClaw 已成功启动！"
echo "============================================"
echo ""
echo "  官方界面: http://127.0.0.1:18789/chat#token=pocketclaw"
echo "  WebChat:  http://127.0.0.1:18789/chat#token=pocketclaw"


# ── 清理明文 ──
if [ -f "$ENC_FILE" ]; then
    secure_wipe "$PROJECT_DIR/.env"
    echo "[安全] 明文配置已安全擦除"
fi

# 打开浏览器
if command -v open &>/dev/null; then
    open "http://127.0.0.1:18789/chat#token=pocketclaw"
elif command -v xdg-open &>/dev/null; then
    xdg-open "http://127.0.0.1:18789/chat#token=pocketclaw"
fi
