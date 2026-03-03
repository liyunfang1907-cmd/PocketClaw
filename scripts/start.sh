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

# ── Docker 就绪检测（5秒超时保护，防止 docker info 在引擎启动中无限挂起）──
docker_is_ready() {
    ( docker info >/dev/null 2>&1 ) &
    local pid=$!
    local i=0
    while [ $i -lt 5 ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            wait "$pid" 2>/dev/null
            return $?
        fi
        sleep 1
        i=$((i + 1))
    done
    # 超时：杀掉挂起的 docker info
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    return 1
}

# ── 等待 Docker 引擎就绪（带超时计数器）──
wait_for_docker() {
    local max_wait=$1
    local label=$2
    echo "       等待 Docker 引擎就绪（最多等待 ${max_wait} 秒）..."
    local elapsed=0
    while ! docker_is_ready; do
        elapsed=$((elapsed + 5))
        if [ "$elapsed" -ge "$max_wait" ]; then
            echo "[错误] Docker ${label}启动超时！请手动启动 Docker Desktop 后重试。"
            exit 1
        fi
        echo "       已等待 ${elapsed} 秒..."
        sleep 5
    done
}

# ── 检查 Docker ──
if ! command -v docker &>/dev/null; then
    echo "[警告] 未检测到 Docker！正在自动安装..."
    echo ""
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: 优先用 brew，没有则直接下载 DMG
        if command -v brew &>/dev/null; then
            echo "[信息] 正在通过 Homebrew 安装 Docker Desktop..."
            brew install --cask docker
        else
            echo "[信息] 正在直接下载 Docker Desktop..."
            if [[ "$(uname -m)" == "arm64" ]]; then
                DMG_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
            else
                DMG_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
            fi
            DMG_FILE="/tmp/Docker.dmg"
            echo "       架构: $(uname -m)"
            echo "       下载地址: $DMG_URL"
            echo "       文件较大（~600MB），请耐心等待..."
            echo ""
            if ! curl -fSL --progress-bar -o "$DMG_FILE" "$DMG_URL"; then
                echo ""
                echo "[错误] Docker Desktop 下载失败！"
                echo "       请手动下载安装: https://www.docker.com/products/docker-desktop/"
                exit 1
            fi
            echo ""
            echo "[信息] 正在安装 Docker Desktop 到 /Applications..."
            hdiutil attach "$DMG_FILE" -nobrowse -quiet
            if ! cp -R "/Volumes/Docker/Docker.app" /Applications/ 2>/dev/null; then
                echo "[信息] 需要管理员权限，请输入 Mac 开机密码:"
                sudo cp -R "/Volumes/Docker/Docker.app" /Applications/
            fi
            hdiutil detach "/Volumes/Docker" -quiet 2>/dev/null || true
            rm -f "$DMG_FILE"
        fi
        echo "[OK] Docker Desktop 已安装"
        echo ""
        echo "[信息] 正在启动 Docker Desktop（首次启动可能需要授权）..."
        open -a "Docker"
    else
        # Linux: 通过官方脚本安装
        echo "[信息] 正在通过官方脚本安装 Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        sudo systemctl start docker 2>/dev/null || true
        echo "[OK] Docker 已安装"
    fi
    echo ""
    wait_for_docker 180 ""
    echo "[OK] Docker 已就绪"
fi

if ! docker_is_ready; then
    if command -v colima &>/dev/null; then
        echo "[信息] Docker 未运行，正在自动启动 Colima..."
        colima start 2>/dev/null || true
        wait_for_docker 120 ""
        echo "[OK] Colima 已自动启动"
    else
        echo "[信息] Docker 未运行，正在自动启动 Docker Desktop..."
        if [[ "$(uname)" == "Darwin" ]]; then
            killall "com.docker.backend" "com.docker.virtualization" 2>/dev/null || true
            sleep 1
        fi
        open -a "Docker" 2>/dev/null || true
        wait_for_docker 120 "Desktop "
        echo "[OK] Docker Desktop 已自动启动"
    fi
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

# ── 清理 .env 中的非 UTF-8 字节（防止 GBK 中文注释导致 docker --env-file 报错）──
if [ -f "$PROJECT_DIR/.env" ]; then
    # 最可靠的方式：去掉 CRLF，然后只保留非注释非空行（KEY=VALUE 格式）
    # Docker 的 --env-file 不需要注释，GBK 注释会导致 invalid utf8 报错
    # LC_ALL=C 确保 macOS 上不会因非 UTF-8 字节报 "Illegal byte sequence"
    LC_ALL=C tr -d '\r' < "$PROJECT_DIR/.env" \
        | LC_ALL=C grep -v '^[[:space:]]*#' \
        | LC_ALL=C grep -v '^[[:space:]]*$' \
        > "$PROJECT_DIR/.env.clean" 2>/dev/null
    if [ -s "$PROJECT_DIR/.env.clean" ]; then
        mv "$PROJECT_DIR/.env.clean" "$PROJECT_DIR/.env"
        echo "[OK] .env 已清理（移除注释和空行）"
    else
        # 清理后为空说明出了问题，保留原文件
        rm -f "$PROJECT_DIR/.env.clean"
        echo "[警告] .env 清理异常，保留原文件"
    fi
fi

# ── 检查/配置 Docker 镜像加速器 ──
# Colima 用户: 镜像加速器通过 ~/.colima/default/colima.yaml 配置，此处跳过
USING_COLIMA=0
if command -v colima &>/dev/null && colima status 2>/dev/null | grep -qi "running"; then
    USING_COLIMA=1
fi

DAEMON_JSON="$HOME/.docker/daemon.json"
MIRRORS_OK=0
if [ "$USING_COLIMA" -eq 1 ]; then
    MIRRORS_OK=1  # Colima 用户跳过镜像加速器检查
elif [ -f "$DAEMON_JSON" ]; then
    if python3 -c "import json; cfg=json.load(open('$DAEMON_JSON')); exit(0 if cfg.get('registry-mirrors') else 1)" 2>/dev/null; then
        MIRRORS_OK=1
    fi
fi

if [ "$MIRRORS_OK" -eq 1 ]; then
    echo "[OK] 镜像加速器已配置，跳过连通性检查"
else
    echo "[信息] 检查 Docker Hub 连通性..."
    # 用 curl 快速检测（5秒超时），比 docker pull 快得多
    if ! curl -s --connect-timeout 5 --max-time 10 https://registry-1.docker.io/v2/ >/dev/null 2>&1; then
        echo ""
        echo "[信息] Docker Hub 不可达，正在自动配置国内镜像加速器..."
        mkdir -p "$(dirname "$DAEMON_JSON")"
        if [ -f "$DAEMON_JSON" ]; then
            python3 -c "
import json
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
        # 仅 Docker Desktop 需要重启
        if [ "$USING_COLIMA" -eq 0 ] && open -a "Docker" 2>/dev/null; then
            echo "[信息] 正在重启 Docker Desktop 以应用配置..."
            osascript -e 'quit app "Docker"' 2>/dev/null || true
            QUIT_WAIT=0
            while docker info &>/dev/null 2>&1; do
                sleep 2
                QUIT_WAIT=$((QUIT_WAIT + 2))
                if [ "$QUIT_WAIT" -ge 30 ]; then
                    break
                fi
            done
            sleep 2
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
            echo "[信息] 镜像加速器配置已写入，将在下次 Docker 启动时生效"
        fi
    else
        echo "[OK] Docker Hub 连接正常"
    fi
fi

# ── 清理 macOS 资源分叉/隐藏文件（防止 Docker 构建失败 + 保持 USB 干净）──
find "$PROJECT_DIR" -maxdepth 2 \( -name '._*' -o -name '.DS_Store' \) -delete 2>/dev/null || true

# 清理 USB 根目录的 macOS 隐藏文件（Spotlight 索引、FSEvents、回收站等）
if [[ "$(uname)" == "Darwin" ]]; then
    USB_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
    # 仅当父目录看起来像 USB 挂载点时才清理
    if [[ "$USB_ROOT" == /Volumes/* ]] || [[ "$USB_ROOT" == /media/* ]] || [[ "$USB_ROOT" == /mnt/* ]]; then
        rm -rf "$USB_ROOT/.Spotlight-V100" "$USB_ROOT/.Trashes" "$USB_ROOT/.fseventsd" 2>/dev/null || true
        rm -f "$USB_ROOT/.DS_Store" 2>/dev/null || true
        # 创建 .metadata_never_index 阻止 Spotlight 索引此驱动器
        touch "$USB_ROOT/.metadata_never_index" 2>/dev/null || true
        # 创建 .fseventsd/no_log 阻止 FSEvents 记录
        mkdir -p "$USB_ROOT/.fseventsd" 2>/dev/null || true
        touch "$USB_ROOT/.fseventsd/no_log" 2>/dev/null || true
        echo "[清理] 已清除 USB 驱动器 macOS 隐藏文件并禁止重新生成"
    fi
fi

# ── 启动 ──
cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/data/logs"
BUILD_LOG="$PROJECT_DIR/data/logs/build.log"
> "$BUILD_LOG"

# ── 版本更新检查（在构建前执行，更新后重新构建新版本）──
POCKETCLAW_VERSION=$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "unknown")
echo "[信息] 正在检查更新..."
VERSION_API="https://pocketclaw-1380766547.cos.ap-beijing.myqcloud.com/version.json"
LATEST_VER=""
DOWNLOAD_URL=""
if command -v curl &>/dev/null; then
    VERSION_JSON=$(curl -sf --connect-timeout 5 "$VERSION_API" 2>/dev/null || true)
    if [ -n "$VERSION_JSON" ]; then
        LATEST_VER=$(echo "$VERSION_JSON" | grep -o '"latest"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
        DOWNLOAD_URL=$(echo "$VERSION_JSON" | grep -o '"download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    fi
fi

if [ -z "$LATEST_VER" ]; then
    echo "[信息] 无法获取版本信息（网络问题），跳过检查"
elif [ "$LATEST_VER" = "$POCKETCLAW_VERSION" ]; then
    echo "[OK] 当前已是最新版本 v${POCKETCLAW_VERSION}"
else
    echo ""
    echo "============================================"
    echo "  [更新] 发现新版本 v${LATEST_VER}"
    echo "         当前版本 v${POCKETCLAW_VERSION}"
    echo "============================================"
    echo ""
    echo "  （更新不会影响您的私有数据和配置）"
    printf "  是否一键更新？(y/N): "
    read -r UPDATE_CHOICE
    if [ "$UPDATE_CHOICE" = "y" ] || [ "$UPDATE_CHOICE" = "Y" ]; then
        echo ""
        echo "[更新] 正在下载更新包..."
        UPDATE_ZIP="/tmp/PocketClaw-update.zip"
        UPDATE_DIR="/tmp/PocketClaw-update"
        if curl -sfL --connect-timeout 30 "$DOWNLOAD_URL" -o "$UPDATE_ZIP" 2>/dev/null; then
            echo "[更新] 下载完成，正在解压..."
            rm -rf "$UPDATE_DIR"
            unzip -qo "$UPDATE_ZIP" -d "$UPDATE_DIR" 2>/dev/null || {
                python3 -c "import zipfile; zipfile.ZipFile('$UPDATE_ZIP').extractall('$UPDATE_DIR')" 2>/dev/null
            }
            PAYLOAD=""
            if [ -d "$UPDATE_DIR/PocketClaw" ]; then
                PAYLOAD="$UPDATE_DIR/PocketClaw"
            else
                for d in "$UPDATE_DIR"/*/; do
                    [ -f "${d}VERSION" ] && PAYLOAD="$d" && break
                done
            fi
            if [ -z "$PAYLOAD" ]; then
                echo "[错误] 更新包格式异常，请手动更新"
            else
                echo "[更新] 正在安装更新..."
                # 复制根目录文件（不覆盖 .env）
                for f in "$PAYLOAD"/*; do
                    [ -f "$f" ] && bn=$(basename "$f") && [ "$bn" != ".env" ] && cp -f "$f" "$PROJECT_DIR/" 2>/dev/null
                done
                # 复制 scripts/
                [ -d "$PAYLOAD/scripts" ] && cp -rf "$PAYLOAD/scripts/"* "$PROJECT_DIR/scripts/" 2>/dev/null
                # 复制 config/ 下的所有文件（mobile.html, voice-chat.js 等）
                [ -d "$PAYLOAD/config" ] && {
                    for cf in "$PAYLOAD/config"/*; do
                        if [ -f "$cf" ]; then
                            cp -f "$cf" "$PROJECT_DIR/config/" 2>/dev/null
                        fi
                    done
                }
                # 复制 config/workspace/ 下的 .md 文件
                [ -d "$PAYLOAD/config/workspace" ] && {
                    for wf in "$PAYLOAD/config/workspace"/*.md; do
                        [ -f "$wf" ] && cp -f "$wf" "$PROJECT_DIR/config/workspace/" 2>/dev/null
                    done
                }
                # 复制 config/workspace/skills/
                [ -d "$PAYLOAD/config/workspace/skills" ] && cp -rf "$PAYLOAD/config/workspace/skills/"* "$PROJECT_DIR/config/workspace/skills/" 2>/dev/null
                NEW_VER=$(cat "$PAYLOAD/VERSION" 2>/dev/null || echo "?")
                POCKETCLAW_VERSION="$NEW_VER"
                # 清除构建哈希，强制重新构建新版本的镜像
                rm -f "$PROJECT_DIR/data/.build_hash"
                echo ""
                echo "============================================"
                echo "  [OK] 更新完成! v${POCKETCLAW_VERSION}"
                echo "       正在继续启动新版本..."
                echo "============================================"
                echo ""
            fi
            rm -rf "$UPDATE_DIR" "$UPDATE_ZIP"
        else
            echo "[错误] 下载失败，请检查网络或手动访问 pocketclaw.cn 下载"
        fi
    else
        echo "  [信息] 已跳过更新，可随时访问 pocketclaw.cn 下载"
    fi
    echo ""
fi

# ── 第一步：智能构建镜像 ──
# 计算关键文件指纹：仅当 Dockerfile/entrypoint/config 变化时才重新构建
BUILD_HASH_FILE="$PROJECT_DIR/data/.build_hash"
CURRENT_HASH=""
if command -v md5sum &>/dev/null; then
    CURRENT_HASH=$(cat "$PROJECT_DIR/Dockerfile.custom" "$PROJECT_DIR/scripts/entrypoint.sh" "$PROJECT_DIR/config/mobile.html" "$PROJECT_DIR/config/voice-chat.js" "$PROJECT_DIR/config/openclaw.json" "$PROJECT_DIR/VERSION" 2>/dev/null | md5sum | awk '{print $1}')
elif command -v md5 &>/dev/null; then
    CURRENT_HASH=$(cat "$PROJECT_DIR/Dockerfile.custom" "$PROJECT_DIR/scripts/entrypoint.sh" "$PROJECT_DIR/config/mobile.html" "$PROJECT_DIR/config/voice-chat.js" "$PROJECT_DIR/config/openclaw.json" "$PROJECT_DIR/VERSION" 2>/dev/null | md5)
fi

PREV_HASH=""
[ -f "$BUILD_HASH_FILE" ] && PREV_HASH=$(cat "$BUILD_HASH_FILE" 2>/dev/null)

NEED_BUILD=1
if [ -n "$CURRENT_HASH" ] && [ "$CURRENT_HASH" = "$PREV_HASH" ]; then
    # 指纹一致，检查镜像是否存在
    if docker image inspect pocketclaw-pocketclaw:latest &>/dev/null; then
        NEED_BUILD=0
        echo "[OK] 镜像未变化，跳过构建（秒级启动）"
    fi
fi

if [ "$NEED_BUILD" -eq 1 ]; then
    echo ""
    echo "┌──────────────────────────────────────────┐"
    echo "│  正在构建容器镜像...                     │"
    echo "│  首次构建约 3-5 分钟，后续有缓存会更快   │"
    echo "└──────────────────────────────────────────┘"
    echo ""

    run_compose build --progress=plain >> "$BUILD_LOG" 2>&1 &
    BUILD_PID=$!

    SPINNER='|/-\'
    SPIN_IDX=0
    BUILD_START=$(date +%s)
    while kill -0 "$BUILD_PID" 2>/dev/null; do
        NOW=$(date +%s)
        ELAPSED=$(( NOW - BUILD_START ))
        MINS=$(( ELAPSED / 60 ))
        SECS=$(( ELAPSED % 60 ))
        STEP=$(grep -oE '\[[[:space:]]*[0-9]+/[0-9]+\][[:space:]]+[A-Z]+[^"]*' "$BUILD_LOG" 2>/dev/null | tail -1 | head -c 50 || true)
        SPIN_CHAR="${SPINNER:SPIN_IDX%4:1}"
        printf "\r  %s [%02d:%02d] %s          " "$SPIN_CHAR" "$MINS" "$SECS" "${STEP:-正在准备...}"
        SPIN_IDX=$((SPIN_IDX + 1))
        sleep 0.5
    done
    wait "$BUILD_PID"
    BUILD_EXIT=$?
    printf "\r%-80s\r" " "

    NOW=$(date +%s)
    BUILD_TOTAL=$(( NOW - BUILD_START ))

    if [ "$BUILD_EXIT" -ne 0 ]; then
        echo ""
        echo "[错误] 镜像构建失败！（耗时 $((BUILD_TOTAL/60))分$((BUILD_TOTAL%60))秒）"
        echo "  构建日志: $BUILD_LOG"
        echo "  可能原因:"
        echo "  1. Docker Hub 无法访问 → 请配置镜像加速器"
        echo "  2. 磁盘空间不足 → docker system prune"
        exit 1
    fi
    echo "[OK] 镜像构建完成（耗时 $((BUILD_TOTAL/60))分$((BUILD_TOTAL%60))秒）"

    # 保存构建指纹
    [ -n "$CURRENT_HASH" ] && echo "$CURRENT_HASH" > "$BUILD_HASH_FILE"
fi

# ── 第二步：启动容器 ──
# 彻底清理所有 pocketclaw 相关容器（包括幽灵容器）和网络
echo "[..] 清理旧容器..."
run_compose down --remove-orphans >> "$BUILD_LOG" 2>&1 || true
# 清理所有名称含 pocketclaw 的容器（包括 <hash>_pocketclaw 等幽灵容器）
for cid in $(docker ps -aq --filter "name=pocketclaw" 2>/dev/null); do
    docker rm -f "$cid" >> "$BUILD_LOG" 2>&1 || true
done
# 清理任何使用 pocketclaw 镜像但名称不匹配的容器
for cid in $(docker ps -aq --filter "ancestor=pocketclaw-pocketclaw:latest" 2>/dev/null); do
    docker rm -f "$cid" >> "$BUILD_LOG" 2>&1 || true
done
# 清理可能残留的网络
docker network rm pocketclaw_pocketclaw-net >> "$BUILD_LOG" 2>&1 || true
docker network rm pocketclaw_default >> "$BUILD_LOG" 2>&1 || true

# ── 生成随机 Gateway Token（每次启动不同，防止局域网未授权访问）──
if [ -z "${GATEWAY_AUTH_PASSWORD:-}" ]; then
    GATEWAY_AUTH_PASSWORD=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 8 || true)
    # 若 urandom 失败，使用时间戳+进程号
    if [ -z "$GATEWAY_AUTH_PASSWORD" ]; then
        GATEWAY_AUTH_PASSWORD="pc$(date +%s | tail -c 7)$$"
    fi
fi
export GATEWAY_AUTH_PASSWORD

# 停止 Mac 原生 OpenClaw gateway (与 Docker 端口冲突)
if [ "$(uname)" = "Darwin" ]; then
    PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
    if [ -f "$PLIST" ] && launchctl list 2>/dev/null | grep -q "ai.openclaw.gateway"; then
        echo "[信息] 正在停止原生 OpenClaw gateway (端口冲突)..."
        launchctl unload "$PLIST" 2>/dev/null || true
        sleep 1
    fi
fi

# 尝试 docker compose up
run_compose up -d >> "$BUILD_LOG" 2>&1 || true

# 等待几秒让容器启动
sleep 3

# 检查容器是否在运行
if docker ps --filter "name=pocketclaw" --format "{{.Status}}" 2>/dev/null | grep -qi "up"; then
    echo "[OK] 容器启动成功"
else
    # docker compose up 失败（可能有幽灵容器干扰），回退到 docker run
    echo "[信息] 正在使用备用方式启动..."
    docker rm -f pocketclaw >> "$BUILD_LOG" 2>&1 || true

    # 从 docker-compose.yml 读取镜像名
    IMAGE_NAME="pocketclaw-pocketclaw:latest"

    # 创建网络（忽略已存在错误）
    docker network create pocketclaw_pocketclaw-net >> "$BUILD_LOG" 2>&1 || true

    # 直接 docker run
    docker run -d \
        --name pocketclaw \
        --restart unless-stopped \
        --network pocketclaw_pocketclaw-net \
        -p 0.0.0.0:18789:18789 \
        -v "$PROJECT_DIR/config/workspace:/home/node/.openclaw/workspace" \
        -v "$PROJECT_DIR/data/credentials:/home/node/.openclaw/credentials" \
        -v "$PROJECT_DIR/data/sessions:/home/node/.openclaw/sessions" \
        -v "$PROJECT_DIR/data/logs:/home/node/.openclaw/logs" \
        -v "$PROJECT_DIR/data/skills:/home/node/.openclaw/skills" \
        --env-file "$PROJECT_DIR/.env" \
        -e "GATEWAY_AUTH_PASSWORD=$GATEWAY_AUTH_PASSWORD" \
        "$IMAGE_NAME" >> "$BUILD_LOG" 2>&1

    sleep 3
    if docker ps --filter "name=pocketclaw" --format "{{.Status}}" 2>/dev/null | grep -qi "up"; then
        echo "[OK] 容器启动成功（备用方式）"
    else
        echo ""
        echo "[错误] 容器启动失败！"
        echo "  构建日志: $BUILD_LOG"
        echo "  可能原因:"
        echo "  1. 端口 18789 被占用 → 关闭占用该端口的程序"
        echo "  2. 磁盘空间不足 → docker system prune"
        echo "  3. Docker 数据损坏 → 打开 Docker Desktop → 设置 → Reset to factory defaults"
        exit 1
    fi
fi
echo "[OK] 构建完成！"

# ── 读取 Gateway Token（用于浏览器自动认证）──
GATEWAY_TOKEN="${GATEWAY_AUTH_PASSWORD:-pocketclaw}"
DASHBOARD_URL="http://127.0.0.1:18789/#token=${GATEWAY_TOKEN}"

# ── 保存 Token 到 workspace（AI 可读取，用于生成手机访问地址）──
echo "$GATEWAY_TOKEN" > "$PROJECT_DIR/config/workspace/.gateway_token"

# ── 检测局域网 IP（用于手机访问）──
LAN_IP=""
if command -v ifconfig &>/dev/null; then
    LAN_IP=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
elif command -v ip &>/dev/null; then
    LAN_IP=$(ip -4 addr show | grep -oE 'inet [0-9.]+' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
elif command -v hostname &>/dev/null; then
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
if [ -n "$LAN_IP" ]; then
    echo "$LAN_IP" > "$PROJECT_DIR/config/workspace/.host_ip"
fi

# 重新读取版本号（可能已被更新）
POCKETCLAW_VERSION=$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "unknown")

echo ""
echo "============================================"
echo "  [OK] PocketClaw v${POCKETCLAW_VERSION} 已成功启动！"
echo "============================================"
echo ""
echo "  打开界面: $DASHBOARD_URL"
if [ -n "$LAN_IP" ]; then
MOBILE_URL="http://${LAN_IP}:18789/mobile.html#token=${GATEWAY_TOKEN}"
echo "  手机访问: $MOBILE_URL"
echo ""
echo "  [扫码手机访问]"
echo ""
# 生成终端 QR 码（优先用容器内 python3，容器已预装 qrcode 模块）
if docker exec pocketclaw python3 -c "import qrcode,sys;qr=qrcode.QRCode(border=1,error_correction=qrcode.constants.ERROR_CORRECT_L);qr.add_data(sys.argv[1]);qr.print_ascii()" "$MOBILE_URL" 2>/dev/null; then
    true
elif command -v python3 &>/dev/null; then
    python3 -c "
try:
    import qrcode
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', '-q', '--break-system-packages', 'qrcode'],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    import qrcode
qr = qrcode.QRCode(border=1, error_correction=qrcode.constants.ERROR_CORRECT_L)
qr.add_data('$MOBILE_URL')
qr.print_ascii()
" 2>/dev/null || true
fi
echo ""
fi


# ── 清理明文 ──
if [ -f "$ENC_FILE" ]; then
    secure_wipe "$PROJECT_DIR/.env"
    echo "[安全] 明文配置已安全擦除"
fi

# 打开浏览器（URL含token，自动完成认证）
if command -v open &>/dev/null; then
    open "$DASHBOARD_URL"
elif command -v xdg-open &>/dev/null; then
    xdg-open "$DASHBOARD_URL"
fi
