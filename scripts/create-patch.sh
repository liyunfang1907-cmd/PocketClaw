#!/usr/bin/env bash
# ============================================================
# create-patch.sh  —— 增量更新补丁生成工具 (D3)
#
# 对比两个版本目录，生成一个轻量级补丁 ZIP，仅包含变化的文件。
# 用户使用 install-update.sh 应用补丁时，只需下载几 KB 而非 300+KB。
#
# 用法:
#   bash scripts/create-patch.sh <旧版本目录> <新版本目录> [输出文件]
#
# 示例:
#   bash scripts/create-patch.sh ../备份文件\ PocketClaw\ v1.2.5/ . patch-1.2.5-to-1.2.6.zip
# ============================================================
set -euo pipefail

OLD_DIR="${1:-}"
NEW_DIR="${2:-.}"
OLD_VER=""
NEW_VER=""

if [ -z "$OLD_DIR" ]; then
    echo "用法: bash scripts/create-patch.sh <旧版本目录> [新版本目录] [输出文件]"
    echo ""
    echo "示例: bash scripts/create-patch.sh '../备份 v1.2.5/' . patch.zip"
    exit 1
fi

if [ ! -d "$OLD_DIR" ]; then
    echo "[错误] 旧版本目录不存在: $OLD_DIR"
    exit 1
fi

OLD_VER=$(cat "$OLD_DIR/VERSION" 2>/dev/null || echo "unknown")
NEW_VER=$(cat "$NEW_DIR/VERSION" 2>/dev/null || echo "unknown")
OUTPUT="${3:-patch-${OLD_VER}-to-${NEW_VER}.zip}"

echo "============================================"
echo "  增量补丁生成器"
echo "  $OLD_VER → $NEW_VER"
echo "============================================"
echo ""

# ── 需要比较的文件/目录 ──
COMPARE_ITEMS=(
    "VERSION"
    "Dockerfile.custom"
    "docker-compose.yml"
    "PocketClaw.command"
    "PocketClaw.bat"
    "README.md"
    "LICENSE.md"
    "使用指南.txt"
    "config/mobile.html"
    "config/openclaw.json"
    "config/providers.json"
    "config/voice-chat.js"
    "config/setup.html"
)

# 动态添加 scripts/ 和 config/workspace/ 下的文件
for f in "$NEW_DIR"/scripts/*; do
    [ -f "$f" ] && COMPARE_ITEMS+=("scripts/$(basename "$f")")
done
for f in "$NEW_DIR"/config/workspace/*.md; do
    [ -f "$f" ] && COMPARE_ITEMS+=("config/workspace/$(basename "$f")")
done
for f in "$NEW_DIR"/config/workspace/skills/*.md; do
    [ -f "$f" ] && COMPARE_ITEMS+=("config/workspace/skills/$(basename "$f")")
done

# ── 对比并收集变化文件 ──
PATCH_DIR="/tmp/pocketclaw-patch-$$"
rm -rf "$PATCH_DIR"
mkdir -p "$PATCH_DIR"

CHANGED=0
ADDED=0
UNCHANGED=0

for item in "${COMPARE_ITEMS[@]}"; do
    NEW_FILE="$NEW_DIR/$item"
    OLD_FILE="$OLD_DIR/$item"
    
    if [ ! -f "$NEW_FILE" ]; then
        continue
    fi

    if [ ! -f "$OLD_FILE" ]; then
        # 新增文件
        mkdir -p "$PATCH_DIR/$(dirname "$item")"
        cp "$NEW_FILE" "$PATCH_DIR/$item"
        echo "  [新增] $item"
        ADDED=$((ADDED + 1))
    elif ! diff -q "$OLD_FILE" "$NEW_FILE" >/dev/null 2>&1; then
        # 修改的文件
        mkdir -p "$PATCH_DIR/$(dirname "$item")"
        cp "$NEW_FILE" "$PATCH_DIR/$item"
        echo "  [修改] $item"
        CHANGED=$((CHANGED + 1))
    else
        UNCHANGED=$((UNCHANGED + 1))
    fi
done

# ── 写入补丁元数据 ──
cat > "$PATCH_DIR/PATCH_INFO.txt" <<EOF
PocketClaw 增量补丁
从 v${OLD_VER} 升级到 v${NEW_VER}
生成时间: $(date '+%Y-%m-%d %H:%M:%S')
变更文件: ${CHANGED} 个修改, ${ADDED} 个新增
EOF

echo ""
echo "统计: $CHANGED 个修改, $ADDED 个新增, $UNCHANGED 个未变"
echo ""

if [ "$CHANGED" -eq 0 ] && [ "$ADDED" -eq 0 ]; then
    echo "[信息] 没有变化，无需生成补丁"
    rm -rf "$PATCH_DIR"
    exit 0
fi

# ── 打包 ──
(cd "$PATCH_DIR" && zip -r - .) > "$OUTPUT" 2>/dev/null || {
    # zip 不可用时用 Python
    python3 -c "
import zipfile, os
with zipfile.ZipFile('$OUTPUT', 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk('$PATCH_DIR'):
        for f in files:
            fp = os.path.join(root, f)
            arcname = os.path.relpath(fp, '$PATCH_DIR')
            zf.write(fp, arcname)
"
}

PATCH_SIZE=$(ls -lh "$OUTPUT" | awk '{print $5}')
echo "[OK] 补丁已生成: $OUTPUT ($PATCH_SIZE)"
echo ""
echo "用户可通过以下方式应用补丁:"
echo "  unzip -o $OUTPUT -d /path/to/PocketClaw/"

rm -rf "$PATCH_DIR"
