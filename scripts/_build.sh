#!/usr/bin/env bash
# ============================================================
# _build.sh  —— Docker 镜像构建模块
# 由 start.sh 通过 source 引入
# ============================================================

# ── 计算构建指纹 ──
compute_build_hash() {
    local PROJECT_DIR=$1
    local FILES=(
        "$PROJECT_DIR/Dockerfile.custom"
        "$PROJECT_DIR/scripts/entrypoint.sh"
        "$PROJECT_DIR/config/mobile.html"
        "$PROJECT_DIR/config/openclaw.json"
        "$PROJECT_DIR/config/providers.json"
        "$PROJECT_DIR/VERSION"
    )
    if command -v md5sum &>/dev/null; then
        cat "${FILES[@]}" 2>/dev/null | md5sum | awk '{print $1}'
    elif command -v md5 &>/dev/null; then
        cat "${FILES[@]}" 2>/dev/null | md5
    fi
}

# ── 智能构建镜像 ──
# 参数: $1=PROJECT_DIR  $2=BUILD_LOG
smart_build() {
    local PROJECT_DIR=$1
    local BUILD_LOG=$2
    local BUILD_HASH_FILE="$PROJECT_DIR/data/.build_hash"

    local CURRENT_HASH
    CURRENT_HASH=$(compute_build_hash "$PROJECT_DIR")

    local PREV_HASH=""
    [ -f "$BUILD_HASH_FILE" ] && PREV_HASH=$(cat "$BUILD_HASH_FILE" 2>/dev/null)

    local NEED_BUILD=1
    if [ -n "$CURRENT_HASH" ] && [ "$CURRENT_HASH" = "$PREV_HASH" ]; then
        if docker image inspect pocketclaw-pocketclaw:latest &>/dev/null; then
            NEED_BUILD=0
            echo "[OK] 镜像未变化，跳过构建（秒级启动）"
        fi
    fi

    # 尝试从 Docker Hub 拉取预构建镜像
    if [ "$NEED_BUILD" -eq 1 ]; then
        local DOCKER_IMAGE="pocketclaw/pocketclaw:latest"
        echo "[5/7] 尝试拉取预构建镜像..."
        if docker pull "$DOCKER_IMAGE" >> "$BUILD_LOG" 2>&1; then
            docker tag "$DOCKER_IMAGE" pocketclaw-pocketclaw:latest >> "$BUILD_LOG" 2>&1
            NEED_BUILD=0
            echo "[OK] 预构建镜像拉取成功，跳过本地构建"
            [ -n "$CURRENT_HASH" ] && echo "$CURRENT_HASH" > "$BUILD_HASH_FILE"
        else
            echo "[信息] 预构建镜像不可用，将进行本地构建"
        fi
    fi

    if [ "$NEED_BUILD" -eq 1 ]; then
        _do_local_build "$PROJECT_DIR" "$BUILD_LOG" "$CURRENT_HASH" "$BUILD_HASH_FILE"
    fi
}

# ── 本地构建 ──
_do_local_build() {
    local PROJECT_DIR=$1
    local BUILD_LOG=$2
    local CURRENT_HASH=$3
    local BUILD_HASH_FILE=$4

    local FIRST_BUILD=0
    if ! docker image inspect pocketclaw-pocketclaw:latest &>/dev/null 2>&1; then
        FIRST_BUILD=1
    fi

    echo ""
    echo "┌──────────────────────────────────────────┐"
    if [ "$FIRST_BUILD" -eq 1 ]; then
    echo "│  首次构建容器镜像（约 5-8 分钟）         │"
    echo "│  需下载 ~800MB 依赖，请保持网络连接      │"
    else
    echo "│  正在构建容器镜像...                     │"
    echo "│  有缓存加速，预计 1-2 分钟               │"
    fi
    echo "└──────────────────────────────────────────┘"
    echo ""

    DOCKER_BUILDKIT=1 run_compose build --progress=plain >> "$BUILD_LOG" 2>&1 &
    local BUILD_PID=$!

    local SPINNER='|/-\'
    local SPIN_IDX=0
    local BUILD_START
    BUILD_START=$(date +%s)
    while kill -0 "$BUILD_PID" 2>/dev/null; do
        local NOW ELAPSED MINS SECS STEP SPIN_CHAR
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
    local BUILD_EXIT=$?
    printf "\r%-80s\r" " "

    NOW=$(date +%s)
    local BUILD_TOTAL=$(( NOW - BUILD_START ))

    if [ "$BUILD_EXIT" -ne 0 ]; then
        echo ""
        echo "[错误] 镜像构建失败！（耗时 $((BUILD_TOTAL/60))分$((BUILD_TOTAL%60))秒）"
        echo "  构建日志: $BUILD_LOG"
        echo "  可能原因:"
        echo "  1. Docker Hub 无法访问 → 请配置镜像加速器"
        echo "  2. 磁盘空间不足 → docker system prune"
        echo ""
        echo "  详细排查指南: https://pocketclaw.cn/#faq"
        exit 1
    fi
    echo "[OK] 镜像构建完成（耗时 $((BUILD_TOTAL/60))分$((BUILD_TOTAL%60))秒）"
    [ -n "$CURRENT_HASH" ] && echo "$CURRENT_HASH" > "$BUILD_HASH_FILE"
}
