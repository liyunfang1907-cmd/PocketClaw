#!/usr/bin/env bash
# ============================================================
# _https.sh  —— mkcert HTTPS 自签证书辅助模块
# 由 start.sh 通过 source 引入
#
# 为局域网手机访问配置 HTTPS（Safari/Chrome 对 HTTP 限制越来越严）
# ============================================================

CERT_DIR="${PROJECT_DIR:-.}/secrets/certs"
CERT_FILE="$CERT_DIR/local.pem"
KEY_FILE="$CERT_DIR/local-key.pem"

# ── 检测并安装 mkcert ──
ensure_mkcert() {
    if command -v mkcert &>/dev/null; then
        return 0
    fi

    echo "[信息] mkcert 未安装，尝试自动安装..."
    if [[ "$(uname)" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
            brew install mkcert nss 2>/dev/null && return 0
        fi
    else
        # Linux
        if command -v apt-get &>/dev/null; then
            sudo apt-get install -y libnss3-tools 2>/dev/null || true
        fi
        # 下载预编译二进制
        local ARCH="amd64"
        [[ "$(uname -m)" == "aarch64" ]] && ARCH="arm64"
        local MKCERT_URL="https://dl.filippo.io/mkcert/latest?for=linux/${ARCH}"
        if curl -sfL "$MKCERT_URL" -o /tmp/mkcert 2>/dev/null; then
            chmod +x /tmp/mkcert
            sudo mv /tmp/mkcert /usr/local/bin/mkcert 2>/dev/null || mv /tmp/mkcert "$HOME/.local/bin/mkcert"
            return 0
        fi
    fi

    echo "[警告] mkcert 安装失败，将使用 HTTP（无 HTTPS）"
    return 1
}

# ── 生成局域网 HTTPS 证书 ──
setup_https_certs() {
    local LAN_IP=${1:-}

    # 如已有证书且未过期（30天内不重新生成），跳过
    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        local CERT_AGE=0
        if [[ "$(uname)" == "Darwin" ]]; then
            CERT_AGE=$(( $(date +%s) - $(stat -f %m "$CERT_FILE") ))
        else
            CERT_AGE=$(( $(date +%s) - $(stat -c %Y "$CERT_FILE") ))
        fi
        # 30天 = 2592000秒
        if [ "$CERT_AGE" -lt 2592000 ]; then
            echo "[OK] HTTPS 证书有效（$((CERT_AGE/86400))天前生成）"
            return 0
        fi
    fi

    if ! ensure_mkcert; then
        return 1
    fi

    echo "[信息] 正在生成本地 HTTPS 证书..."
    mkdir -p "$CERT_DIR"

    # 安装本地 CA
    mkcert -install 2>/dev/null || true

    # 生成证书（包含 localhost + 局域网 IP）
    local DOMAINS=("localhost" "127.0.0.1" "::1")
    [ -n "$LAN_IP" ] && DOMAINS+=("$LAN_IP")

    mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" "${DOMAINS[@]}" 2>/dev/null

    if [ -f "$CERT_FILE" ]; then
        echo "[OK] HTTPS 证书已生成"
        echo "     证书: $CERT_FILE"
        echo "     域名: ${DOMAINS[*]}"
        return 0
    else
        echo "[警告] 证书生成失败"
        return 1
    fi
}

# ── 获取 HTTPS URL（如果证书可用）──
get_https_url() {
    local HOST=$1
    local PORT=${2:-18789}
    local TOKEN=$3

    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        echo "https://${HOST}:${PORT}/#token=${TOKEN}"
    else
        echo "http://${HOST}:${PORT}/#token=${TOKEN}"
    fi
}
