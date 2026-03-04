#!/usr/bin/env bash
# ============================================================
# sign-release.sh  —— 发布包签名与校验工具 (D6)
#
# 使用 Ed25519 对发布 ZIP 进行签名，用户可验证包的真实性。
# 比 GPG 更简单，无需 keyserver。
#
# 用法:
#   bash scripts/sign-release.sh sign   <file.zip>   # 签名
#   bash scripts/sign-release.sh verify <file.zip>    # 验证
#   bash scripts/sign-release.sh keygen               # 生成密钥对
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PRIVATE_KEY="$PROJECT_DIR/secrets/sign.key"
PUBLIC_KEY="$PROJECT_DIR/secrets/sign.pub"

# ── 帮助 ──
usage() {
    echo "用法:"
    echo "  bash scripts/sign-release.sh keygen                # 生成 Ed25519 密钥对"
    echo "  bash scripts/sign-release.sh sign   <file.zip>     # 对文件签名"
    echo "  bash scripts/sign-release.sh verify <file.zip>     # 验证签名"
    echo ""
    echo "签名文件: <file>.sig  (与原文件同目录)"
    echo "公钥文件: secrets/sign.pub"
    exit 1
}

# ── 检查 openssl 版本（需要 1.1.1+ 支持 Ed25519）──
check_openssl() {
    if ! command -v openssl &>/dev/null; then
        echo "[错误] 未找到 openssl，请先安装"
        exit 1
    fi
    local VER
    VER=$(openssl version 2>/dev/null | awk '{print $2}')
    echo "[信息] OpenSSL 版本: $VER"
}

# ── 生成密钥对 ──
do_keygen() {
    check_openssl
    
    if [ -f "$PRIVATE_KEY" ]; then
        echo "[警告] 私钥已存在: $PRIVATE_KEY"
        printf "  覆盖？(y/N): "
        read -r CONFIRM
        [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && exit 0
    fi

    mkdir -p "$PROJECT_DIR/secrets"
    
    # 生成 Ed25519 私钥
    openssl genpkey -algorithm Ed25519 -out "$PRIVATE_KEY" 2>/dev/null
    chmod 600 "$PRIVATE_KEY"
    
    # 导出公钥
    openssl pkey -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY" 2>/dev/null
    
    echo ""
    echo "[OK] Ed25519 密钥对已生成"
    echo "  私钥: $PRIVATE_KEY  (⚠️ 请安全保管，勿提交到 Git)"
    echo "  公钥: $PUBLIC_KEY   (应随发布包分发)"
    echo ""
    echo "公钥内容:"
    cat "$PUBLIC_KEY"
    
    # 添加到 .gitignore
    GITIGNORE="$PROJECT_DIR/.gitignore"
    if [ -f "$GITIGNORE" ]; then
        if ! grep -q "sign.key" "$GITIGNORE" 2>/dev/null; then
            echo "secrets/sign.key" >> "$GITIGNORE"
        fi
    fi
}

# ── 签名 ──
do_sign() {
    local FILE=$1
    check_openssl
    
    if [ ! -f "$FILE" ]; then
        echo "[错误] 文件不存在: $FILE"
        exit 1
    fi
    
    if [ ! -f "$PRIVATE_KEY" ]; then
        echo "[错误] 私钥不存在: $PRIVATE_KEY"
        echo "  请先运行: bash scripts/sign-release.sh keygen"
        exit 1
    fi
    
    local SIG_FILE="${FILE}.sig"
    local HASH_FILE="${FILE}.sha256"
    
    # 计算 SHA-256
    if command -v sha256sum &>/dev/null; then
        sha256sum "$FILE" | awk '{print $1}' > "$HASH_FILE"
    else
        shasum -a 256 "$FILE" | awk '{print $1}' > "$HASH_FILE"
    fi
    
    # Ed25519 签名
    openssl pkeyutl -sign -inkey "$PRIVATE_KEY" \
        -rawin -in "$FILE" \
        -out "$SIG_FILE" 2>/dev/null
    
    local FILE_SIZE
    FILE_SIZE=$(ls -lh "$FILE" | awk '{print $5}')
    local SIG_SIZE
    SIG_SIZE=$(ls -lh "$SIG_FILE" | awk '{print $5}')
    
    echo ""
    echo "[OK] 签名完成"
    echo "  文件:     $FILE ($FILE_SIZE)"
    echo "  SHA-256:  $(cat "$HASH_FILE")"
    echo "  签名:     $SIG_FILE ($SIG_SIZE)"
    echo ""
    echo "验证命令:"
    echo "  bash scripts/sign-release.sh verify $FILE"
}

# ── 验证 ──
do_verify() {
    local FILE=$1
    check_openssl
    
    if [ ! -f "$FILE" ]; then
        echo "[错误] 文件不存在: $FILE"
        exit 1
    fi
    
    local SIG_FILE="${FILE}.sig"
    local HASH_FILE="${FILE}.sha256"
    local PUB_KEY=""
    
    # 查找公钥（优先当前目录，然后 secrets/）
    if [ -f "$PUBLIC_KEY" ]; then
        PUB_KEY="$PUBLIC_KEY"
    elif [ -f "./sign.pub" ]; then
        PUB_KEY="./sign.pub"
    else
        echo "[错误] 找不到公钥文件"
        echo "  期望路径: $PUBLIC_KEY 或当前目录 sign.pub"
        exit 1
    fi
    
    echo "验证文件: $FILE"
    
    # 检查 SHA-256
    local RESULT_SHA="❌"
    if [ -f "$HASH_FILE" ]; then
        local EXPECTED ACTUAL
        EXPECTED=$(cat "$HASH_FILE")
        if command -v sha256sum &>/dev/null; then
            ACTUAL=$(sha256sum "$FILE" | awk '{print $1}')
        else
            ACTUAL=$(shasum -a 256 "$FILE" | awk '{print $1}')
        fi
        if [ "$EXPECTED" = "$ACTUAL" ]; then
            RESULT_SHA="✅"
        fi
    else
        RESULT_SHA="⏭️ (无 .sha256 文件)"
    fi
    echo "  SHA-256:  $RESULT_SHA"
    
    # 验证 Ed25519 签名
    local RESULT_SIG="❌"
    if [ -f "$SIG_FILE" ]; then
        if openssl pkeyutl -verify -pubin -inkey "$PUB_KEY" \
            -rawin -in "$FILE" -sigfile "$SIG_FILE" 2>/dev/null; then
            RESULT_SIG="✅"
        fi
    else
        RESULT_SIG="⏭️ (无 .sig 文件)"
    fi
    echo "  签名:     $RESULT_SIG"
    
    echo ""
    if [[ "$RESULT_SHA" == "✅" ]] && [[ "$RESULT_SIG" == "✅" ]]; then
        echo "[OK] 验证通过 — 文件完整且来自可信发布者"
    elif [[ "$RESULT_SHA" == "❌" ]] || [[ "$RESULT_SIG" == "❌" ]]; then
        echo "[错误] 验证失败 — 文件可能被篡改！"
        exit 1
    else
        echo "[警告] 部分校验文件缺失，无法完全验证"
    fi
}

# ── 主入口 ──
ACTION="${1:-}"
case "$ACTION" in
    keygen)
        do_keygen
        ;;
    sign)
        [ -z "${2:-}" ] && usage
        do_sign "$2"
        ;;
    verify)
        [ -z "${2:-}" ] && usage
        do_verify "$2"
        ;;
    *)
        usage
        ;;
esac
