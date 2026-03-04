#!/usr/bin/env bash
# ============================================================
# _docker.sh  —— Docker 安装与启动辅助模块
# 由 start.sh 通过 source 引入
# ============================================================

# ── Docker 就绪检测（5秒超时保护）──
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

# ── 安装 Docker Desktop DMG（macOS）──
install_docker_dmg() {
    local arch_name="arm64"
    [[ "$(uname -m)" != "arm64" ]] && arch_name="amd64"
    local DMG_FILE="/tmp/Docker.dmg"
    local DMG_URL="https://desktop.docker.com/mac/main/${arch_name}/Docker.dmg"
    echo "[信息] 正在直接下载 Docker Desktop..."
    echo "       架构: $(uname -m)"
    echo "       文件较大（~600MB），请耐心等待..."
    echo ""
    if ! curl -fSL --connect-timeout 15 --retry 2 --progress-bar -o "$DMG_FILE" "$DMG_URL"; then
        rm -f "$DMG_FILE"
        return 1
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
    return 0
}

# ── 配置 Docker 镜像加速器 ──
configure_docker_mirrors() {
    local USING_COLIMA=$1
    local DAEMON_JSON="$HOME/.docker/daemon.json"
    local MIRRORS_OK=0

    if [ "$USING_COLIMA" -eq 1 ]; then
        MIRRORS_OK=1
    elif [ -f "$DAEMON_JSON" ]; then
        if python3 -c "import json; cfg=json.load(open('$DAEMON_JSON')); exit(0 if cfg.get('registry-mirrors') else 1)" 2>/dev/null; then
            MIRRORS_OK=1
        fi
    fi

    if [ "$MIRRORS_OK" -eq 1 ]; then
        echo "[OK] 镜像加速器已配置，跳过连通性检查"
        return 0
    fi

    echo "[信息] 检查 Docker Hub 连通性..."
    if curl -s --connect-timeout 5 --max-time 10 https://registry-1.docker.io/v2/ >/dev/null 2>&1; then
        echo "[OK] Docker Hub 连接正常"
        return 0
    fi

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
        local QUIT_WAIT=0
        while docker info &>/dev/null 2>&1; do
            sleep 2
            QUIT_WAIT=$((QUIT_WAIT + 2))
            [ "$QUIT_WAIT" -ge 30 ] && break
        done
        sleep 2
        open -a "Docker"
        wait_for_docker 120 "Desktop "
        echo "[OK] Docker 已重启，镜像加速器已生效"
    else
        echo "[信息] 镜像加速器配置已写入，将在下次 Docker 启动时生效"
    fi
}

# ── 清理容器/网络 ──
docker_cleanup_containers() {
    local LOG_FILE=$1
    echo "[..] 清理旧容器..."
    run_compose down --remove-orphans >> "$LOG_FILE" 2>&1 || true
    for cid in $(docker ps -aq --filter "name=pocketclaw" 2>/dev/null); do
        docker rm -f "$cid" >> "$LOG_FILE" 2>&1 || true
    done
    for cid in $(docker ps -aq --filter "ancestor=pocketclaw-pocketclaw:latest" 2>/dev/null); do
        docker rm -f "$cid" >> "$LOG_FILE" 2>&1 || true
    done
    docker network rm pocketclaw_pocketclaw-net >> "$LOG_FILE" 2>&1 || true
    docker network rm pocketclaw_default >> "$LOG_FILE" 2>&1 || true
}
