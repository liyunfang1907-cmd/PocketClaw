#!/usr/bin/env bash
# ============================================================
# Doctor.command — PocketClaw 独立诊断修复工具
# 双击即可运行，不依赖 PocketClaw.command
# ============================================================
cd "$(dirname "$0")" || exit 1
bash scripts/doctor.sh
echo ""
read -rp "  按回车关闭窗口..." _
