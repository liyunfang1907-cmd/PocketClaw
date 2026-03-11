#!/usr/bin/env bash
# ============================================================
# PocketClaw 公共函数库
# 用法: source "$(dirname "$0")/scripts/_common.sh"
#       或 source "$(dirname "$0")/_common.sh"
# ============================================================

# ── 颜色输出 ──
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
cyan()  { printf "\033[36m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

# ── 跨平台 sed -i（macOS / Linux 兼容）──
# 用法: sed_inplace 's/old/new/' file.txt
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# ── Docker Compose v1/v2 兼容封装 ──
# 用法: run_compose up -d --build
#       run_compose down
run_compose() {
    if docker compose version &>/dev/null; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

# ── 安全擦除文件（多次覆写 + 删除）──
# 用法: secure_wipe "/path/to/file"
secure_wipe() {
    local file="$1"
    if [ -f "$file" ]; then
        local size
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || wc -c < "$file" 2>/dev/null || echo 0)
        if [ "$size" -gt 0 ] 2>/dev/null; then
            dd if=/dev/zero of="$file" bs=1 count="$size" conv=notrunc 2>/dev/null
            dd if=/dev/urandom of="$file" bs=1 count="$size" conv=notrunc 2>/dev/null
            dd if=/dev/zero of="$file" bs=1 count="$size" conv=notrunc 2>/dev/null
            sync 2>/dev/null || true
        fi
        rm -f "$file"
    fi
}

# ── 项目目录检测 ──
# 用法: detect_project_dir
# 设置 PROJECT_DIR 变量
detect_project_dir() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)"
    # 如果在 scripts/ 子目录中，上移一级
    if [ "$(basename "$script_dir")" = "scripts" ]; then
        PROJECT_DIR="$(dirname "$script_dir")"
    else
        PROJECT_DIR="$script_dir"
    fi
    export PROJECT_DIR
}

# ── OpenSSL 加密 .env → .env.encrypted ──
# 用法: encrypt_env_file "$ENV_FILE" "$ENC_FILE" "$PASSWORD"
# 返回: 0=成功, 1=失败
encrypt_env_file() {
    local env_file="$1" enc_file="$2" password="$3"
    printf '%s' "$password" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 600000 \
        -in "$env_file" -out "$enc_file" -pass stdin 2>/dev/null
}

# ── OpenSSL 解密 .env.encrypted → .env ──
# 用法: decrypt_env_file "$ENC_FILE" "$ENV_FILE" "$PASSWORD"
# 返回: 0=成功, 1=失败
# 兼容旧版: 先尝试 600K 迭代，失败则回退到 100K
decrypt_env_file() {
    local enc_file="$1" env_file="$2" password="$3"
    if printf '%s' "$password" | openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 600000 \
        -in "$enc_file" -out "$env_file" -pass stdin 2>/dev/null; then
        return 0
    fi
    # 回退: 旧版 100K 迭代
    if printf '%s' "$password" | openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
        -in "$enc_file" -out "$env_file" -pass stdin 2>/dev/null; then
        echo "[信息] 检测到旧版加密格式，建议重新加密以提升安全性" >&2
        return 0
    fi
    return 1
}

# ── 清理 macOS 在 USB 上生成的隐藏文件 ──
# 用法: clean_macos_usb_artifacts "$PROJECT_DIR"
clean_macos_usb_artifacts() {
    local proj_dir="$1"
    # 清理项目内的资源分叉和 .DS_Store
    find "$proj_dir" -maxdepth 2 \( -name '._*' -o -name '.DS_Store' \) -delete 2>/dev/null || true
    # 清理 USB 根目录
    if [[ "$(uname)" == "Darwin" ]]; then
        local usb_root=""
        local parent_dir
        parent_dir="$(cd "$proj_dir/.." 2>/dev/null && pwd)"
        case "$parent_dir" in
            /Volumes/*|/media/*|/mnt/*)
                usb_root="$parent_dir"
                ;;
        esac
        if [ -n "$usb_root" ]; then
            rm -rf "$usb_root/.Spotlight-V100" "$usb_root/.Trashes" "$usb_root/.fseventsd" 2>/dev/null || true
            rm -f "$usb_root/.DS_Store" "$usb_root/.metadata_never_index" 2>/dev/null || true
            find "$usb_root" -name "._*" -delete 2>/dev/null || true
            # 阻止 Spotlight 索引和 FSEvents 记录
            touch "$usb_root/.metadata_never_index" 2>/dev/null || true
            mkdir -p "$usb_root/.fseventsd" 2>/dev/null || true
            touch "$usb_root/.fseventsd/no_log" 2>/dev/null || true
        fi
    fi
}
