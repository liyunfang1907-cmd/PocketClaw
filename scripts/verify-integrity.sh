#!/usr/bin/env bash
# ============================================================
# verify-integrity.sh  —— 文件完整性校验工具
#
# 检测关键脚本文件是否被篡改。生成或验证 SHA-256 校验和。
#
# 用法:
#   bash scripts/verify-integrity.sh          # 验证完整性
#   bash scripts/verify-integrity.sh --init   # 生成校验文件（维护者用）
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKSUM_FILE="$PROJECT_DIR/scripts/.checksums.sha256"

# ── 颜色 ──
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }

# ── 需要校验的关键文件 ──
FILES=(
    "scripts/start.sh"
    "scripts/start.bat"
    "scripts/stop.sh"
    "scripts/stop.bat"
    "scripts/setup-env.sh"
    "scripts/setup-env.bat"
    "scripts/encrypt-secrets.sh"
    "scripts/encrypt.bat"
    "scripts/decrypt-secrets.sh"
    "scripts/decrypt.bat"
    "scripts/change-api.bat"
    "scripts/change-api.sh"
    "scripts/_common.sh"
    "scripts/backup.sh"
    "scripts/backup.bat"
    "scripts/reset.sh"
    "scripts/reset.bat"
    "scripts/install-update.sh"
    "scripts/install-update.bat"
    "scripts/entrypoint.sh"
    "scripts/setup-channels.sh"
    "scripts/setup-channels.bat"
    "scripts/verify-integrity.sh"
    "docker-compose.yml"
    "Dockerfile.custom"
    "config/openclaw.json"
    "PocketClaw.bat"
    "PocketClaw.command"
)

# ── 生成校验文件 ──
if [[ "${1:-}" == "--init" ]]; then
    echo ""
    echo "正在生成文件校验和..."
    > "$CHECKSUM_FILE"
    for f in "${FILES[@]}"; do
        if [[ -f "$PROJECT_DIR/$f" ]]; then
            HASH=$(shasum -a 256 "$PROJECT_DIR/$f" | awk '{print $1}')
            echo "$HASH  $f" >> "$CHECKSUM_FILE"
            echo "  ✓ $f"
        fi
    done
    echo ""
    green "[完成] 校验文件已生成: scripts/.checksums.sha256"
    echo "       共 $(wc -l < "$CHECKSUM_FILE" | tr -d ' ') 个文件"
    exit 0
fi

# ── 验证完整性 ──
echo ""
echo "╔══════════════════════════════════════╗"
echo "║   PocketClaw 文件完整性校验        ║"
echo "╚══════════════════════════════════════╝"
echo ""

if [[ ! -f "$CHECKSUM_FILE" ]]; then
    yellow "[警告] 未找到校验文件 (scripts/.checksums.sha256)"
    echo "       跳过完整性校验。"
    echo "       维护者可运行: bash scripts/verify-integrity.sh --init"
    exit 0
fi

PASS=0
FAIL=0
MISSING=0

while IFS='  ' read -r expected_hash filepath; do
    # 跳过空行
    [[ -z "$expected_hash" ]] && continue

    if [[ ! -f "$PROJECT_DIR/$filepath" ]]; then
        yellow "  ✗ $filepath — 文件缺失"
        MISSING=$((MISSING + 1))
        continue
    fi

    actual_hash=$(shasum -a 256 "$PROJECT_DIR/$filepath" | awk '{print $1}')

    if [[ "$actual_hash" == "$expected_hash" ]]; then
        green "  ✓ $filepath"
        PASS=$((PASS + 1))
    else
        red "  ✗ $filepath — 已被修改"
        FAIL=$((FAIL + 1))
    fi
done < "$CHECKSUM_FILE"

echo ""
echo "──────────────────────────────────────"
echo "  通过: $PASS  |  修改: $FAIL  |  缺失: $MISSING"
echo "──────────────────────────────────────"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    yellow "[警告] 检测到 $FAIL 个文件被修改。"
    echo "       如果不是你自己修改的，请注意安全风险。"
    echo "       修改后的文件不受原作者技术支持。"
fi

if [[ $FAIL -eq 0 && $MISSING -eq 0 ]]; then
    green "[通过] 所有文件完整性校验通过 ✓"
fi

echo ""
