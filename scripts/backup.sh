#!/usr/bin/env bash
# ============================================================
# backup.sh  —— 将 PocketClaw 关键文件备份到本地
# 默认备份路径: ~/PocketClaw_Backup/
# 用法: bash scripts/backup.sh [target_dir]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 备份目标目录 (可通过参数覆盖)
BACKUP_DIR="${1:-$HOME/PocketClaw_Backup}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SNAPSHOT_DIR="$BACKUP_DIR/snapshot_$TIMESTAMP"

echo ""
yellow "=== PocketClaw 备份工具 ==="
echo "源目录: $PROJECT_DIR"
echo "备份到: $SNAPSHOT_DIR"
echo ""

# --------------- 创建备份目录 ---------------
mkdir -p "$SNAPSHOT_DIR"

# --------------- 需要备份的内容 ---------------
ITEMS=(
    "config"
    "secrets"
    "scripts"
    "docker-compose.yml"
    "Dockerfile.custom"
    ".env.example"
    ".gitignore"
    "README.md"
    "VERSION"
    "LICENSE.md"
    "PocketClaw.bat"
    "PocketClaw.command"
)

# 可选: 备份数据 (会话 / 日志 / 自定义 Skill)
OPTIONAL_ITEMS=(
    "data/credentials"
    "data/sessions"
    "data/skills"
)

echo "[1/3] 备份核心文件..."
for item in "${ITEMS[@]}"; do
    src="$PROJECT_DIR/$item"
    if [ -e "$src" ]; then
        if [ -d "$src" ]; then
            cp -R "$src" "$SNAPSHOT_DIR/"
            echo "  + $item/"
        else
            cp "$src" "$SNAPSHOT_DIR/"
            echo "  + $item"
        fi
    else
        echo "  - $item (不存在, 跳过)"
    fi
done

echo ""
echo "[2/3] 备份可选数据..."
for item in "${OPTIONAL_ITEMS[@]}"; do
    src="$PROJECT_DIR/$item"
    if [ -e "$src" ]; then
        dest_dir="$SNAPSHOT_DIR/$(dirname "$item")"
        mkdir -p "$dest_dir"
        cp -R "$src" "$dest_dir/"
        echo "  ✓ $item/"
    else
        echo "  - $item (不存在, 跳过)"
    fi
done

echo ""
echo "[3/3] 生成备份清单..."
# 生成文件清单
find "$SNAPSHOT_DIR" -type f | sed "s|$SNAPSHOT_DIR/||" | sort > "$SNAPSHOT_DIR/MANIFEST.txt"
FILE_COUNT=$(wc -l < "$SNAPSHOT_DIR/MANIFEST.txt" | tr -d ' ')
BACKUP_SIZE=$(du -sh "$SNAPSHOT_DIR" | cut -f1)

echo ""
green "=== 备份完成 ==="
echo "  路径: $SNAPSHOT_DIR"
echo "  文件数: $FILE_COUNT"
echo "  大小: $BACKUP_SIZE"
echo ""

# --------------- 清理旧备份 (保留最近5个) ---------------
TOTAL_SNAPSHOTS=$(ls -d "$BACKUP_DIR"/snapshot_* 2>/dev/null | wc -l | tr -d ' ')
if [ "$TOTAL_SNAPSHOTS" -gt 5 ]; then
    DELETE_COUNT=$((TOTAL_SNAPSHOTS - 5))
    yellow "[信息] 清理旧备份 (保留最近5个, 删除 $DELETE_COUNT 个)..."
    ls -d "$BACKUP_DIR"/snapshot_* 2>/dev/null | sort | head -n "$DELETE_COUNT" | while read -r old; do
        rm -rf "$old"
        echo "  已删除: $(basename "$old")"
    done
fi

# 同步最新的 README 到备份根目录
if [ -f "$PROJECT_DIR/README.md" ]; then
    cp "$PROJECT_DIR/README.md" "$BACKUP_DIR/README.md"
fi

green "[完成] 全部完成!"
