#!/usr/bin/env bash
# ============================================================
# doctor.sh  —— PocketClaw 自诊断修复工具 (macOS/Linux)
# 用法: bash scripts/doctor.sh
# ============================================================
set -uo pipefail

# ── 公共函数库 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

trap 'unset AI_API_KEY 2>/dev/null' EXIT

# ── 颜色与图标 ──
PASS="✅"
FAIL="❌"
WARN="⚠️"
INFO="ℹ️"

# ── 版本 ──
POCKETCLAW_VERSION=$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "unknown")

# ── 诊断结果收集 ──
TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0
REPORT=""        # 纯文本报告
REPORT_FILE=""   # 报告文件路径
PROBLEMS=""      # 问题摘要（给 AI 分析用）

add_result() {
    local status="$1" name="$2" detail="$3"
    TOTAL=$((TOTAL + 1))
    case "$status" in
        pass) PASSED=$((PASSED + 1)); REPORT+="  $PASS $name\n" ;;
        fail) FAILED=$((FAILED + 1)); REPORT+="  $FAIL $name — $detail\n"
              PROBLEMS+="[FAIL] $name: $detail\n" ;;
        warn) WARNINGS=$((WARNINGS + 1)); REPORT+="  $WARN $name — $detail\n"
              PROBLEMS+="[WARN] $name: $detail\n" ;;
    esac
}

echo ""
echo "============================================"
echo "  PocketClaw Doctor v${POCKETCLAW_VERSION}"
echo "  自诊断修复工具"
echo "============================================"
echo ""
echo "  正在检查 11 个诊断项..."
echo ""

# ══════════════════════════════════════════════
# [1/11] Docker 安装
# ══════════════════════════════════════════════
echo -n "  [1/11] Docker 安装..."
if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | head -1)
    add_result pass "Docker 安装" "$DOCKER_VER"
    echo " $PASS"
else
    add_result fail "Docker 安装" "未检测到 docker 命令，请安装 Docker Desktop"
    echo " $FAIL 未安装"
    echo ""
    echo "  [!] Docker 未安装，后续检查无法继续。"
    echo "      请先运行 PocketClaw 启动器安装 Docker，或访问 docker.com 下载。"
    # Docker 不存在则后续检查无意义，直接跳到报告
    REPORT="$REPORT"
    TOTAL=10; FAILED=$((FAILED + 9))
    # 跳到报告输出
    SKIP_REST=1
fi

# ══════════════════════════════════════════════
# [2/11] Docker 引擎运行
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [2/11] Docker 引擎..."
if docker info &>/dev/null; then
    add_result pass "Docker 引擎" "运行中"
    echo " $PASS"
else
    add_result fail "Docker 引擎" "Docker 已安装但引擎未运行，请启动 Docker Desktop"
    echo " $FAIL 未运行"
fi
fi

# ══════════════════════════════════════════════
# [3/11] 镜像存在性
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [3/11] Docker 镜像..."
if docker image inspect pocketclaw-pocketclaw:latest &>/dev/null; then
    IMG_SIZE=$(docker image inspect pocketclaw-pocketclaw:latest --format '{{.Size}}' 2>/dev/null)
    IMG_MB=$(( ${IMG_SIZE:-0} / 1024 / 1024 ))
    add_result pass "Docker 镜像" "pocketclaw-pocketclaw:latest (${IMG_MB}MB)"
    echo " $PASS"
else
    add_result fail "Docker 镜像" "镜像不存在，需要运行启动器构建"
    echo " $FAIL 不存在"
fi
fi

# ══════════════════════════════════════════════
# [4/11] 容器状态
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [4/11] 容器状态..."
CONTAINER_STATUS=$(docker ps -a --filter "name=pocketclaw" --format "{{.Status}}" 2>/dev/null | head -1)
if [ -z "$CONTAINER_STATUS" ]; then
    add_result fail "容器状态" "pocketclaw 容器不存在，需要运行启动器"
    echo " $FAIL 不存在"
elif echo "$CONTAINER_STATUS" | grep -qi "up"; then
    # 检查健康状态
    HEALTH=$(docker inspect --format '{{.State.Health.Status}}' pocketclaw 2>/dev/null || echo "none")
    if [ "$HEALTH" = "healthy" ]; then
        add_result pass "容器状态" "运行中 (healthy)"
        echo " $PASS healthy"
    elif [ "$HEALTH" = "unhealthy" ]; then
        add_result warn "容器状态" "运行中但不健康 (unhealthy)，可能启动中或服务异常"
        echo " $WARN unhealthy"
    else
        add_result pass "容器状态" "运行中 ($CONTAINER_STATUS)"
        echo " $PASS"
    fi
else
    add_result fail "容器状态" "容器已停止: $CONTAINER_STATUS"
    echo " $FAIL 已停止"
fi
fi

# ══════════════════════════════════════════════
# [5/11] 端口 18789 与健康检查
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [5/11] 服务端口..."
if curl -sf --connect-timeout 3 --max-time 5 -o /dev/null http://127.0.0.1:18789/health 2>/dev/null; then
    add_result pass "服务端口" "18789 端口正常响应"
    echo " $PASS"
else
    # 端口是否被其他进程占用
    PORT_PID=$(lsof -ti:18789 2>/dev/null || ss -tlnp 2>/dev/null | grep 18789 | head -1 || true)
    if [ -n "$PORT_PID" ] && ! docker ps --filter "name=pocketclaw" --format "{{.ID}}" 2>/dev/null | head -1 | grep -q .; then
        add_result fail "服务端口" "端口 18789 被其他进程占用 (PID: $PORT_PID)"
        echo " $FAIL 被占用"
    else
        add_result fail "服务端口" "18789 无响应，容器可能未正常启动或服务崩溃"
        echo " $FAIL 无响应"
    fi
fi
fi

# ══════════════════════════════════════════════
# [6/11] .provider 文件
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [6/11] .provider 配置..."
PROVIDER_FILE="$PROJECT_DIR/config/workspace/.provider"
if [ -f "$PROVIDER_FILE" ]; then
    # 检查必要字段
    HAS_PROVIDER=$(grep -c '^PROVIDER_NAME=' "$PROVIDER_FILE" 2>/dev/null || echo 0)
    HAS_KEY=$(grep -c '^API_KEY=' "$PROVIDER_FILE" 2>/dev/null || echo 0)
    PROV_NAME=$(grep '^PROVIDER_NAME=' "$PROVIDER_FILE" 2>/dev/null | cut -d= -f2 | tr -d ' \r')
    if [ "$HAS_PROVIDER" -gt 0 ] && [ "$HAS_KEY" -gt 0 ]; then
        add_result pass ".provider 配置" "提供商: ${PROV_NAME:-unknown}, 字段完整"
        echo " $PASS"
    else
        MISSING=""
        [ "$HAS_PROVIDER" -eq 0 ] && MISSING+="PROVIDER_NAME "
        [ "$HAS_KEY" -eq 0 ] && MISSING+="API_KEY "
        add_result warn ".provider 配置" "缺少字段: $MISSING"
        echo " $WARN 字段不全"
    fi
else
    add_result warn ".provider 配置" "文件不存在（将使用 .env 中的配置）"
    echo " $WARN 不存在"
fi
fi

# ══════════════════════════════════════════════
# [7/11] API Key 配置
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [7/11] API Key..."
API_KEY_FOUND=""
# 优先从 .provider 读取
if [ -f "$PROJECT_DIR/config/workspace/.provider" ]; then
    API_KEY_FOUND=$(grep '^API_KEY=' "$PROJECT_DIR/config/workspace/.provider" 2>/dev/null | cut -d= -f2 | tr -d ' \r')
fi
# 回退到容器环境变量
if [ -z "$API_KEY_FOUND" ]; then
    API_KEY_FOUND=$(docker exec pocketclaw sh -c 'printf "%s" "$OPENAI_API_KEY"' 2>/dev/null || true)
fi
if [ -n "$API_KEY_FOUND" ] && [ "$API_KEY_FOUND" != "not-configured-yet" ]; then
    # 脱敏显示（只显示前4和后4位）
    KEY_LEN=${#API_KEY_FOUND}
    if [ "$KEY_LEN" -gt 12 ]; then
        MASKED="${API_KEY_FOUND:0:4}****${API_KEY_FOUND:$((KEY_LEN-4))}"
    else
        MASKED="****"
    fi
    add_result pass "API Key" "已配置 ($MASKED)"
    echo " $PASS"
else
    add_result fail "API Key" "未配置或为空，AI 功能无法使用"
    echo " $FAIL 未配置"
fi
fi

# ══════════════════════════════════════════════
# [8/11] .env 加密状态
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [8/11] 配置加密..."
ENC_FILE="$PROJECT_DIR/secrets/.env.encrypted"
ENV_FILE="$PROJECT_DIR/.env"
if [ -f "$ENC_FILE" ]; then
    if [ -f "$ENV_FILE" ]; then
        add_result warn ".env 加密" "存在加密文件，但明文 .env 也存在（应在启动后自动清除）"
        echo " $WARN 明文残留"
    else
        add_result pass ".env 加密" "配置已加密保护"
        echo " $PASS"
    fi
elif [ -f "$ENV_FILE" ]; then
    add_result warn ".env 加密" "配置未加密（建议运行 encrypt 命令加密保护 API Key）"
    echo " $WARN 未加密"
else
    add_result warn ".env 加密" "无 .env 也无加密文件（配置可能通过 .provider 提供）"
    echo " $WARN"
fi
fi

# ══════════════════════════════════════════════
# [9/11] 磁盘空间
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [9/11] 磁盘空间..."
# 检查项目目录所在磁盘
DISK_AVAIL=$(df -m "$PROJECT_DIR" 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "$DISK_AVAIL" ]; then
    if [ "$DISK_AVAIL" -lt 500 ]; then
        add_result fail "磁盘空间" "项目磁盘仅剩 ${DISK_AVAIL}MB，低于 500MB 阈值"
        echo " $FAIL ${DISK_AVAIL}MB"
    elif [ "$DISK_AVAIL" -lt 2000 ]; then
        add_result warn "磁盘空间" "项目磁盘剩余 ${DISK_AVAIL}MB，建议清理"
        echo " $WARN ${DISK_AVAIL}MB"
    else
        add_result pass "磁盘空间" "剩余 ${DISK_AVAIL}MB"
        echo " $PASS"
    fi
else
    add_result warn "磁盘空间" "无法检测磁盘空间"
    echo " $WARN"
fi
fi

# ══════════════════════════════════════════════
# [10/11] 容器日志分析
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [10/11] 容器日志..."
CONTAINER_LOGS=""
if docker ps --filter "name=pocketclaw" --format "{{.ID}}" 2>/dev/null | head -1 | grep -q .; then
    CONTAINER_LOGS=$(docker logs pocketclaw --tail 50 2>&1 || true)
    # 检查常见错误模式
    ERR_COUNT=$(echo "$CONTAINER_LOGS" | grep -ci "error\|fatal\|crash\|panic\|ECONNREFUSED" 2>/dev/null || echo 0)
    if [ "$ERR_COUNT" -gt 5 ]; then
        LAST_ERR=$(echo "$CONTAINER_LOGS" | grep -i "error\|fatal" | tail -1 | head -c 120)
        add_result warn "容器日志" "发现 ${ERR_COUNT} 条错误记录，最近: $LAST_ERR"
        echo " $WARN ${ERR_COUNT} 条错误"
    elif [ "$ERR_COUNT" -gt 0 ]; then
        add_result pass "容器日志" "发现 ${ERR_COUNT} 条错误（可能是正常重试）"
        echo " $PASS"
    else
        add_result pass "容器日志" "无异常"
        echo " $PASS"
    fi
else
    add_result warn "容器日志" "容器未运行，无法检查日志"
    echo " $WARN 无容器"
fi
fi


# ══════════════════════════════════════════════
# [11/11] Docker 网络连通性
# ══════════════════════════════════════════════
if [ "${SKIP_REST:-0}" != "1" ]; then
echo -n "  [11/11] Docker 网络..."
if docker ps --filter "name=pocketclaw" --filter "status=running" --format "{{.ID}}" 2>/dev/null | head -1 | grep -q .; then
    NET_OK=$(docker exec pocketclaw sh -c "curl -sf --connect-timeout 5 https://www.baidu.com -o /dev/null && echo OK" 2>/dev/null || true)
    if [ "$NET_OK" = "OK" ]; then
        add_result pass "Docker 网络" "容器可正常访问外网"
        echo " $PASS"
    else
        add_result fail "Docker 网络" "容器无法连接外部网络，请检查 Docker 网络设置或代理"
        echo " $FAIL 无法访问外网"
    fi
else
    add_result warn "Docker 网络" "容器未运行，无法检测网络"
    echo " $WARN 容器未运行"
fi
fi

# ══════════════════════════════════════════════
# 诊断结果汇总
# ══════════════════════════════════════════════
echo ""
echo "--------------------------------------------"
echo "  诊断完成: $TOTAL 项检查"
echo "  $PASS 通过: $PASSED  $FAIL 失败: $FAILED  $WARN 警告: $WARNINGS"
echo "--------------------------------------------"
echo ""
printf "$REPORT"
echo ""

# ══════════════════════════════════════════════
# AI 智能分析（始终运行）
# ══════════════════════════════════════════════
echo ""
echo "--------------------------------------------"
echo "  $INFO AI 智能分析"
echo "--------------------------------------------"
echo ""

# 检查是否有 curl
if ! command -v curl &>/dev/null; then
    echo "  [跳过] 需要 curl 命令才能调用 AI 分析"
else
    # 从 .provider 或环境读取 iFlow API Key
    AI_API_KEY=""
    if [ -f "$PROJECT_DIR/config/workspace/.provider" ]; then
        AI_API_KEY=$(grep '^API_KEY=' "$PROJECT_DIR/config/workspace/.provider" 2>/dev/null | cut -d= -f2 | tr -d ' \r')
    fi
    # 回退：从容器环境读取
    if [ -z "$AI_API_KEY" ]; then
        AI_API_KEY=$(docker exec pocketclaw sh -c 'printf "%s" "$OPENAI_API_KEY"' 2>/dev/null || true)
    fi
    # 无 Key 时提示用户输入
    if [ -z "$AI_API_KEY" ] || [ "$AI_API_KEY" = "not-configured-yet" ]; then
        echo "  [提示] 未检测到已配置的 API Key"
        echo ""
        echo "  请输入 API Key 以启用 AI 分析（支持 OpenAI 兼容 API）"
        echo "  获取免费 Key: https://cloud.siliconflow.cn"
        echo "  （直接按回车跳过 AI 分析）"
        echo ""
        printf "  API Key: "
        read -r USER_KEY
        if [ -n "$USER_KEY" ]; then
            AI_API_KEY="$USER_KEY"
        else
            echo "  [跳过] 未提供 API Key，跳过 AI 分析"
            AI_API_KEY=""
        fi
    fi

    if [ -z "$AI_API_KEY" ]; then
        # 用户选择跳过 AI 分析，直接跳到后续步骤
        :
    else

    echo "  正在调用 AI 分析..."
    echo ""

    # 收集系统信息
    SYS_INFO="OS: $(uname -s) $(uname -m)"
    SYS_INFO+=", Docker: $(docker --version 2>/dev/null | head -c 40 || echo N/A)"
    SYS_INFO+=", Version: $POCKETCLAW_VERSION"

    # 构造 AI prompt
    if [ -n "$PROBLEMS" ]; then
        AI_PROMPT="你是 PocketClaw 项目的技术支持专家。用户运行了自诊断工具，发现以下问题：

系统信息: $SYS_INFO

诊断结果:
$(printf "$PROBLEMS")

$(if [ -n "$CONTAINER_LOGS" ]; then echo "最近容器日志(最后20行):"; echo "$CONTAINER_LOGS" | tail -20; fi)

请用中文回复，针对每个问题：
1. 简要说明可能原因
2. 给出具体修复命令或操作步骤
3. 如果有自动修复方案，说明修复命令

要求：简洁实用，不要客套话，直接给修复方案。用纯文本格式，不要 Markdown。"
    else
        AI_PROMPT="你是 PocketClaw 项目的技术支持专家。用户运行了自诊断工具，所有 $TOTAL 项检查均通过。

系统信息: $SYS_INFO

$(if [ -n "$CONTAINER_LOGS" ]; then echo "最近容器日志(最后20行):"; echo "$CONTAINER_LOGS" | tail -20; fi)

请用中文回复：
1. 确认系统状态良好
2. 给出 2-3 条优化建议或日常维护提示
3. 如果日志中有任何潜在隐患，指出来

要求：简洁实用，用纯文本格式，不要 Markdown。"
    fi

    # 转义 JSON（用 python3 处理特殊字符）
    AI_JSON=$(python3 -c "
import json, sys
prompt = sys.stdin.read()
payload = {
    'model': 'qwen3-coder-plus',
    'messages': [{'role': 'user', 'content': prompt}],
    'max_tokens': 1000,
    'temperature': 0.3
}
print(json.dumps(payload))
" <<< "$AI_PROMPT" 2>/dev/null)

    if [ -n "$AI_JSON" ]; then
        AI_RESPONSE=$(curl -s --max-time 30 \
            -X POST "https://apis.iflow.cn/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $AI_API_KEY" \
            -d "$AI_JSON" 2>/dev/null)

        AI_REPLY=$(echo "$AI_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except:
    print('AI 分析暂时不可用（API 调用失败）')
" 2>/dev/null)

        if [ -n "$AI_REPLY" ]; then
            echo "  ┌─ AI 分析结果 ─────────────────────────┐"
            echo ""
            echo "$AI_REPLY" | sed 's/^/  /'
            echo ""
            echo "  └───────────────────────────────────────┘"
        fi
    else
        echo "  [跳过] 无法构造 AI 请求（需要 python3）"
    fi

    fi  # end if [ -z "$AI_API_KEY" ]
fi

# ══════════════════════════════════════════════
# AI 对话模式
# ══════════════════════════════════════════════
echo ""
echo "  如需进一步咨询，可与 AI 继续对话"
printf "  是否开启对话模式？(y/N): "
read -r CHAT_CHOICE
if [ "$CHAT_CHOICE" = "y" ] || [ "$CHAT_CHOICE" = "Y" ]; then
    while true; do
        echo ""
        printf "  你的问题 (输入 q 退出): "
        read -r USER_Q
        if [ -z "$USER_Q" ] || [ "$USER_Q" = "q" ] || [ "$USER_Q" = "quit" ] || [ "$USER_Q" = "exit" ]; then
            echo "  对话结束"
            break
        fi
        echo "  正在分析..."
        CHAT_PROMPT="你是 PocketClaw 技术支持专家。用户问题: $USER_Q 系统: $SYS_INFO"
        if [ -n "$PROBLEMS" ]; then
            CHAT_PROMPT="$CHAT_PROMPT 已知问题: $(printf "$PROBLEMS")"
        fi
        CHAT_JSON=$(python3 -c "
import json, sys
prompt = sys.stdin.read()
payload = {
    'model': 'qwen3-coder-plus',
    'messages': [{'role': 'user', 'content': prompt}],
    'max_tokens': 1000,
    'temperature': 0.3
}
print(json.dumps(payload))
" <<< "$CHAT_PROMPT" 2>/dev/null)
        if [ -n "$CHAT_JSON" ]; then
            CHAT_RESP=$(curl -s --max-time 30 \
                -X POST "https://apis.iflow.cn/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $AI_API_KEY" \
                -d "$CHAT_JSON" 2>/dev/null)
            CHAT_REPLY=$(echo "$CHAT_RESP" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except:
    print('AI 分析暂时不可用')
" 2>/dev/null)
            echo ""
            echo "  --- AI 回复 ---"
            echo "$CHAT_REPLY" | sed 's/^/  /'
            echo "  ----------------"
        else
            echo "  [错误] 无法构造请求"
        fi
    done
fi


# ══════════════════════════════════════════════
# 自动修复（有可修复问题时提示）
# ══════════════════════════════════════════════
if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo "--------------------------------------------"
    echo "  🔧 自动修复"
    echo "--------------------------------------------"
    echo ""

    CAN_FIX=0

    # 修复1: 容器停止 → 自动重启
    if docker ps -a --filter "name=pocketclaw" --filter "status=exited" --format "{{.ID}}" 2>/dev/null | head -1 | grep -q .; then
        CAN_FIX=$((CAN_FIX + 1))
        echo "  [可修复] 容器已停止，可尝试重启"
    fi

    # 修复2: 端口无响应但容器在运行 → 重启容器
    if docker ps --filter "name=pocketclaw" --format "{{.ID}}" 2>/dev/null | head -1 | grep -q . && \
       ! curl -sf --connect-timeout 2 http://127.0.0.1:18789/health &>/dev/null; then
        CAN_FIX=$((CAN_FIX + 1))
        echo "  [可修复] 服务无响应，可尝试重启容器"
    fi

    # 修复3: 磁盘空间不足 → docker system prune
    if [ "${DISK_AVAIL:-9999}" -lt 500 ] 2>/dev/null; then
        CAN_FIX=$((CAN_FIX + 1))
        echo "  [可修复] 磁盘空间不足，可清理 Docker 缓存"
    fi

    if [ "$CAN_FIX" -gt 0 ]; then
        echo ""
        printf "  是否尝试自动修复？(y/N): "
        read -r FIX_CHOICE
        if [ "$FIX_CHOICE" = "y" ] || [ "$FIX_CHOICE" = "Y" ]; then
            echo ""

            # 执行修复: 重启容器
            if docker ps -a --filter "name=pocketclaw" --filter "status=exited" --format "{{.ID}}" 2>/dev/null | head -1 | grep -q . || \
               (docker ps --filter "name=pocketclaw" --format "{{.ID}}" 2>/dev/null | head -1 | grep -q . && \
                ! curl -sf --connect-timeout 2 http://127.0.0.1:18789/health &>/dev/null); then
                echo "  [修复] 正在重启容器..."
                cd "$PROJECT_DIR" || true
                run_compose restart 2>/dev/null || docker restart pocketclaw 2>/dev/null || true
                sleep 5
                if curl -sf --connect-timeout 5 http://127.0.0.1:18789/health &>/dev/null; then
                    echo "  $PASS 容器重启成功，服务已恢复"
                else
                    echo "  $WARN 容器已重启，但服务可能需要更长时间启动"
                    echo "       请等待 30 秒后重新运行 doctor"
                fi
            fi

            # 执行修复: 清理 Docker 缓存
            if [ "${DISK_AVAIL:-9999}" -lt 500 ] 2>/dev/null; then
                echo "  [修复] 正在清理 Docker 未使用的缓存..."
                docker system prune -f 2>/dev/null || true
                echo "  $PASS Docker 缓存已清理"
            fi

            echo ""
            echo "  修复完成。建议重新运行 doctor 确认结果。"
        else
            echo "  [跳过] 已跳过自动修复"
        fi
    else
        echo "  当前问题需要手动处理，请参考上方 AI 分析建议。"
    fi
fi

# ══════════════════════════════════════════════
# 导出诊断报告
# ══════════════════════════════════════════════
echo ""
echo "--------------------------------------------"
echo "  📋 导出诊断报告"
echo "--------------------------------------------"
mkdir -p "$PROJECT_DIR/data/logs"
REPORT_FILE="$PROJECT_DIR/data/logs/doctor-$(date +%Y%m%d-%H%M%S).txt"
{
    echo "PocketClaw Doctor 诊断报告"
    echo "=========================="
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "版本: $POCKETCLAW_VERSION"
    echo "系统: $(uname -s) $(uname -m) $(uname -r)"
    echo "Docker: $(docker --version 2>/dev/null || echo N/A)"
    echo ""
    echo "诊断结果: $TOTAL 项检查, 通过 $PASSED, 失败 $FAILED, 警告 $WARNINGS"
    echo ""
    printf "$REPORT"
    echo ""
    if [ -n "$PROBLEMS" ]; then
        echo "问题详情:"
        printf "$PROBLEMS"
        echo ""
    fi
    if [ -n "$CONTAINER_LOGS" ]; then
        echo "容器日志(最后30行):"
        echo "$CONTAINER_LOGS" | tail -30
        echo ""
    fi
    if [ -n "${AI_REPLY:-}" ]; then
        echo "AI 分析:"
        echo "$AI_REPLY"
    fi
} > "$REPORT_FILE"
echo ""
echo "  报告已保存: $REPORT_FILE"
echo ""

# ══════════════════════════════════════════════
# 结束
# ══════════════════════════════════════════════
if [ "$FAILED" -eq 0 ]; then
    echo "  ✅ PocketClaw 运行正常！"
else
    echo "  ❗ 发现 $FAILED 个问题需要关注"
fi
echo ""