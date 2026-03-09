#!/usr/bin/env bash
# ============================================================
# _update.sh  —— 版本更新检查与安装模块
# 由 start.sh 通过 source 引入
# ============================================================

# ── 检查并安装更新 ──
# 参数: $1=PROJECT_DIR  返回: POCKETCLAW_VERSION 可能被更新
check_and_update() {
    local PROJECT_DIR=$1
    POCKETCLAW_VERSION=$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "unknown")
    echo "[信息] 正在检查更新..."

    local VERSION_API="https://pocketclaw.cn/downloads/version.json"
    local VERSION_API_BACKUP="https://raw.githubusercontent.com/pocketclaw/pocketclaw/main/version.json"
    local LATEST_VER="" DOWNLOAD_URL="" DOWNLOAD_URL_BACKUP="" VERSION_JSON=""

    if command -v curl &>/dev/null; then
        VERSION_JSON=$(curl -sf --connect-timeout 5 "$VERSION_API" 2>/dev/null || \
                       curl -sf --connect-timeout 5 "$VERSION_API_BACKUP" 2>/dev/null || true)
        if [ -n "$VERSION_JSON" ]; then
            # 兼容 "latest" 和 "version" 两种字段名
            LATEST_VER=$(echo "$VERSION_JSON" | grep -o '"latest"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
            [ -z "$LATEST_VER" ] && LATEST_VER=$(echo "$VERSION_JSON" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
            DOWNLOAD_URL=$(echo "$VERSION_JSON" | grep -o '"download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
            [ -z "$DOWNLOAD_URL" ] && DOWNLOAD_URL=$(echo "$VERSION_JSON" | grep -o '"cos_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
            DOWNLOAD_URL_BACKUP=$(echo "$VERSION_JSON" | grep -o '"download_url_backup"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
        fi
    fi

    if [ -z "$LATEST_VER" ]; then
        echo "[信息] 无法获取版本信息（网络问题），跳过检查"
        return 0
    fi

    if [ "$LATEST_VER" = "$POCKETCLAW_VERSION" ]; then
        echo "[OK] 当前已是最新版本 v${POCKETCLAW_VERSION}"
        return 0
    fi

    echo ""
    echo "============================================"
    echo "  [更新] 发现新版本 v${LATEST_VER}"
    echo "         当前版本 v${POCKETCLAW_VERSION}"
    echo "============================================"
    echo ""
    echo "  （更新不会影响您的私有数据和配置）"
    printf "  是否一键更新？(y/N): "
    read -r UPDATE_CHOICE
    if [ "$UPDATE_CHOICE" != "y" ] && [ "$UPDATE_CHOICE" != "Y" ]; then
        echo "  [信息] 已跳过更新，可随时访问 pocketclaw.cn 下载"
        echo ""
        return 0
    fi

    _do_update "$PROJECT_DIR" "$DOWNLOAD_URL" "$DOWNLOAD_URL_BACKUP"
}

# ── 执行更新 ──
_do_update() {
    local PROJECT_DIR=$1
    local DOWNLOAD_URL=$2
    local DOWNLOAD_URL_BACKUP=$3

    echo ""
    echo "[更新] 正在下载更新包..."
    local UPDATE_ZIP="/tmp/PocketClaw-update.zip"
    local UPDATE_DIR="/tmp/PocketClaw-update"
    local DL_OK=0

    if curl -sfL --connect-timeout 30 "$DOWNLOAD_URL" -o "$UPDATE_ZIP" 2>/dev/null; then
        DL_OK=1
    elif [ -n "$DOWNLOAD_URL_BACKUP" ]; then
        echo "[信息] 主下载源不可用，尝试备用源..."
        if curl -sfL --connect-timeout 30 "$DOWNLOAD_URL_BACKUP" -o "$UPDATE_ZIP" 2>/dev/null; then
            DL_OK=1
        fi
    fi

    if [ "$DL_OK" -ne 1 ]; then
        echo "[错误] 下载失败，请检查网络或手动访问 pocketclaw.cn 下载"
        return 1
    fi

    echo "[更新] 下载完成，正在解压..."
    rm -rf "$UPDATE_DIR"
    unzip -qo "$UPDATE_ZIP" -d "$UPDATE_DIR" 2>/dev/null || {
        python3 -c "import zipfile; zipfile.ZipFile('$UPDATE_ZIP').extractall('$UPDATE_DIR')" 2>/dev/null
    }

    local PAYLOAD=""
    if [ -d "$UPDATE_DIR/PocketClaw" ]; then
        PAYLOAD="$UPDATE_DIR/PocketClaw"
    else
        for d in "$UPDATE_DIR"/*/; do
            [ -f "${d}VERSION" ] && PAYLOAD="$d" && break
        done
    fi

    if [ -z "$PAYLOAD" ]; then
        echo "[错误] 更新包格式异常，请手动更新"
        rm -rf "$UPDATE_DIR" "$UPDATE_ZIP"
        return 1
    fi

    echo "[更新] 正在安装更新..."
    # 复制根目录文件（不覆盖 .env）
    for f in "$PAYLOAD"/*; do
        [ -f "$f" ] && bn=$(basename "$f") && [ "$bn" != ".env" ] && cp -f "$f" "$PROJECT_DIR/" 2>/dev/null
    done
    [ -d "$PAYLOAD/scripts" ] && cp -rf "$PAYLOAD/scripts/"* "$PROJECT_DIR/scripts/" 2>/dev/null
    [ -d "$PAYLOAD/config" ] && {
        for cf in "$PAYLOAD/config"/*; do
            [ -f "$cf" ] && cp -f "$cf" "$PROJECT_DIR/config/" 2>/dev/null
        done
    }
    [ -d "$PAYLOAD/config/workspace" ] && {
        for wf in "$PAYLOAD/config/workspace"/*.md; do
            [ -f "$wf" ] && cp -f "$wf" "$PROJECT_DIR/config/workspace/" 2>/dev/null
        done
    }
    [ -d "$PAYLOAD/config/workspace/skills" ] && cp -rf "$PAYLOAD/config/workspace/skills/"* "$PROJECT_DIR/config/workspace/skills/" 2>/dev/null

    local NEW_VER
    NEW_VER=$(cat "$PAYLOAD/VERSION" 2>/dev/null || echo "?")
    POCKETCLAW_VERSION="$NEW_VER"
    rm -f "$PROJECT_DIR/data/.build_hash"

    echo ""
    echo "============================================"
    echo "  [OK] 更新完成! v${POCKETCLAW_VERSION}"
    echo "       正在继续启动新版本..."
    echo "============================================"
    echo ""
    rm -rf "$UPDATE_DIR" "$UPDATE_ZIP"
}
