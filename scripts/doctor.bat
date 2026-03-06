@echo off
setlocal EnableDelayedExpansion
title PocketClaw Doctor
color 0B

REM 项目目录
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"

REM 版本
set "PC_VERSION=unknown"
if exist "%PROJECT_DIR%\VERSION" (
    set /p PC_VERSION=<"%PROJECT_DIR%\VERSION"
)

REM 诊断计数器
set "TOTAL=0"
set "PASSED=0"
set "FAILED=0"
set "WARNINGS=0"
set "SKIP_REST=0"
set "PROBLEMS="
set "CAN_FIX=0"
set "DISK_FREE_MB=9999"

echo.
echo ============================================
echo   PocketClaw Doctor v%PC_VERSION%
echo   自诊断修复工具
echo ============================================
echo.
echo   正在检查 11 个诊断项...
echo.

REM ============================================
REM [1/11] Docker 安装
REM ============================================
set /a TOTAL+=1
set /p "=  [1/11] Docker 安装..." <nul
docker --version >nul 2>&1
if !ERRORLEVEL! equ 0 (
    set /a PASSED+=1
    echo  [OK]
) else (
    set /a FAILED+=1
    echo  [失败] 未安装
    echo.
    echo   Docker 未安装，后续检查无法继续。
    echo   请先运行 PocketClaw 启动器安装 Docker。
    set "PROBLEMS=!PROBLEMS![FAIL] Docker 安装: 未检测到 docker 命令 & "
    set /a TOTAL=11
    set /a FAILED+=10
    set "SKIP_REST=1"
)
if "!SKIP_REST!"=="1" goto :summary

REM ============================================
REM [2/11] Docker 引擎运行
REM ============================================
set /a TOTAL+=1
set /p "=  [2/11] Docker 引擎..." <nul
docker info >nul 2>&1
if !ERRORLEVEL! equ 0 (
    set /a PASSED+=1
    echo  [OK]
) else (
    set /a FAILED+=1
    echo  [失败] 未运行
    set "PROBLEMS=!PROBLEMS![FAIL] Docker 引擎: 已安装但未运行，请启动 Docker Desktop & "
)

REM ============================================
REM [3/11] Docker 镜像
REM ============================================
set /a TOTAL+=1
set /p "=  [3/11] Docker 镜像..." <nul
docker image inspect pocketclaw-pocketclaw:latest >nul 2>&1
if !ERRORLEVEL! equ 0 (
    set /a PASSED+=1
    echo  [OK]
) else (
    set /a FAILED+=1
    echo  [失败] 不存在
    set "PROBLEMS=!PROBLEMS![FAIL] Docker 镜像: 镜像不存在，需运行启动器构建 & "
)

REM ============================================
REM [4/11] 容器状态
REM ============================================
set /a TOTAL+=1
set /p "=  [4/11] 容器状态..." <nul
set "C_STATUS="
for /f "tokens=*" %%i in ('docker ps -a --filter "name=pocketclaw" --format "{{.Status}}" 2^>nul') do set "C_STATUS=%%i"
if "!C_STATUS!"=="" (
    set /a FAILED+=1
    echo  [失败] 不存在
    set "PROBLEMS=!PROBLEMS![FAIL] 容器状态: pocketclaw 容器不存在 & "
) else (
    echo !C_STATUS! | findstr /i "Up" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo !C_STATUS! | findstr /i "unhealthy" >nul 2>&1
        if !ERRORLEVEL! equ 0 (
            set /a WARNINGS+=1
            echo  [警告] unhealthy
            set "PROBLEMS=!PROBLEMS![WARN] 容器状态: 运行中但不健康 & "
        ) else (
            set /a PASSED+=1
            echo  [OK] !C_STATUS!
        )
    ) else (
        set /a FAILED+=1
        echo  [失败] 已停止
        set "PROBLEMS=!PROBLEMS![FAIL] 容器状态: 容器已停止 !C_STATUS! & "
    )
)

REM ============================================
REM [5/11] 端口与健康检查
REM ============================================
set /a TOTAL+=1
set /p "=  [5/11] 服务端口..." <nul
curl.exe -sf --connect-timeout 3 http://127.0.0.1:18789/health >nul 2>&1
if !ERRORLEVEL! equ 0 (
    set /a PASSED+=1
    echo  [OK]
) else (
    set /a FAILED+=1
    echo  [失败] 无响应
    set "PROBLEMS=!PROBLEMS![FAIL] 服务端口: 18789 无响应 & "
)

REM ============================================
REM [6/11] .provider 配置文件
REM ============================================
set /a TOTAL+=1
set /p "=  [6/11] .provider 配置..." <nul
set "PROV_FILE=%PROJECT_DIR%\config\workspace\.provider"
if exist "!PROV_FILE!" (
    findstr /b "PROVIDER_NAME=" "!PROV_FILE!" >nul 2>&1
    set "HAS_PROV=!ERRORLEVEL!"
    findstr /b "API_KEY=" "!PROV_FILE!" >nul 2>&1
    set "HAS_AKEY=!ERRORLEVEL!"
    if !HAS_PROV! equ 0 if !HAS_AKEY! equ 0 (
        set /a PASSED+=1
        echo  [OK]
    ) else (
        set /a WARNINGS+=1
        echo  [警告] 字段不全
        set "PROBLEMS=!PROBLEMS![WARN] .provider 配置: 缺少必要字段 & "
    )
) else (
    set /a WARNINGS+=1
    echo  [警告] 不存在
    set "PROBLEMS=!PROBLEMS![WARN] .provider 配置: 文件不存在 & "
)

REM ============================================
REM [7/11] API Key 配置
REM ============================================
set /a TOTAL+=1
set /p "=  [7/11] API Key..." <nul
set "API_KEY_FOUND="
if exist "!PROV_FILE!" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "API_KEY=" "!PROV_FILE!" 2^>nul') do set "API_KEY_FOUND=%%b"
)
if "!API_KEY_FOUND!"=="" (
    for /f "tokens=*" %%k in ('docker exec pocketclaw sh -c "echo $OPENAI_API_KEY" 2^>nul') do set "API_KEY_FOUND=%%k"
)
if "!API_KEY_FOUND!"=="" (
    set /a FAILED+=1
    echo  [失败] 未配置
    set "PROBLEMS=!PROBLEMS![FAIL] API Key: 未配置或为空 & "
) else if "!API_KEY_FOUND!"=="not-configured-yet" (
    set /a FAILED+=1
    echo  [失败] 未配置
    set "PROBLEMS=!PROBLEMS![FAIL] API Key: 未配置 & "
) else (
    set /a PASSED+=1
    echo  [OK]
)

REM ============================================
REM [8/11] .env 加密状态
REM ============================================
set /a TOTAL+=1
set /p "=  [8/11] 配置加密..." <nul
set "ENC_FILE=%PROJECT_DIR%\secrets\.env.encrypted"
set "ENV_FILE=%PROJECT_DIR%\.env"
if exist "!ENC_FILE!" (
    if exist "!ENV_FILE!" (
        set /a WARNINGS+=1
        echo  [警告] 明文残留
        set "PROBLEMS=!PROBLEMS![WARN] 加密: 存在加密文件但明文 .env 也存在 & "
    ) else (
        set /a PASSED+=1
        echo  [OK] 已加密
    )
) else if exist "!ENV_FILE!" (
    set /a WARNINGS+=1
    echo  [警告] 未加密
    set "PROBLEMS=!PROBLEMS![WARN] 加密: 配置未加密，建议运行 encrypt & "
) else (
    set /a WARNINGS+=1
    echo  [警告]
    set "PROBLEMS=!PROBLEMS![WARN] 加密: 无 .env 也无加密文件 & "
)

REM ============================================
REM [9/11] 磁盘空间
REM ============================================
set /a TOTAL+=1
set /p "=  [9/11] 磁盘空间..." <nul
set "DRIVE_LETTER=%PROJECT_DIR:~0,1%"
set "DISK_FREE_MB=0"
for /f %%f in ('powershell -NoProfile -Command "[math]::Floor((Get-PSDrive !DRIVE_LETTER!).Free / 1MB)" 2^>nul') do set "DISK_FREE_MB=%%f"
if !DISK_FREE_MB! lss 500 (
    set /a FAILED+=1
    echo  [失败] 仅剩 !DISK_FREE_MB!MB
    set "PROBLEMS=!PROBLEMS![FAIL] 磁盘空间: 仅剩 !DISK_FREE_MB!MB，低于 500MB & "
) else if !DISK_FREE_MB! lss 2000 (
    set /a WARNINGS+=1
    echo  [警告] !DISK_FREE_MB!MB
    set "PROBLEMS=!PROBLEMS![WARN] 磁盘空间: 剩余 !DISK_FREE_MB!MB，建议清理 & "
) else (
    set /a PASSED+=1
    echo  [OK]
)

REM ============================================
REM [10/11] 容器日志分析
REM ============================================
set /a TOTAL+=1
set /p "=  [10/11] 容器日志..." <nul
set "LOG_ERRS=0"
docker ps --filter "name=pocketclaw" --format "{{.ID}}" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    for /f %%n in ('docker logs pocketclaw --tail 50 2^>^&1 ^| findstr /i /c:"error" /c:"fatal" /c:"crash" /c:"panic" 2^>nul ^| find /c /v ""') do set "LOG_ERRS=%%n"
    if !LOG_ERRS! gtr 5 (
        set /a WARNINGS+=1
        echo  [警告] !LOG_ERRS! 条错误
        set "PROBLEMS=!PROBLEMS![WARN] 容器日志: 发现 !LOG_ERRS! 条错误记录 & "
    ) else (
        set /a PASSED+=1
        echo  [OK]
    )
) else (
    set /a WARNINGS+=1
    echo  [警告] 无容器
    set "PROBLEMS=!PROBLEMS![WARN] 容器日志: 容器未运行，无法检查 & "
)


REM ============================================
REM [11/11] Docker 网络连通性
REM ============================================
set /a TOTAL+=1
set /p "=  [11/11] Docker 网络..." <nul
docker ps --filter "name=pocketclaw" --filter "status=running" --format "{{.ID}}" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    set "NET_OK=0"
    for /f "tokens=*" %%r in ('docker exec pocketclaw sh -c "curl -sf --connect-timeout 5 https://www.baidu.com -o /dev/null && echo OK" 2^>nul') do (
        if "%%r"=="OK" set "NET_OK=1"
    )
    if !NET_OK! equ 1 (
        set /a PASSED+=1
        echo  [OK]
    ) else (
        set /a FAILED+=1
        echo  [失败] 容器无法访问外网
        set "PROBLEMS=!PROBLEMS![FAIL] Docker 网络: 容器无法连接外部网络，请检查 Docker 网络设置或代理 & "
    )
) else (
    set /a WARNINGS+=1
    echo  [跳过] 容器未运行
    set "PROBLEMS=!PROBLEMS![WARN] Docker 网络: 容器未运行，无法检测网络 & "
)

:summary
echo.
echo ============================================
echo   诊断完成: !TOTAL! 项检查
echo   通过: !PASSED!  失败: !FAILED!  警告: !WARNINGS!
echo ============================================
echo.

REM （始终执行 AI 分析，不跳过）

REM ============================================
REM AI 智能分析
REM ============================================
echo --------------------------------------------
echo   AI 智能分析
echo --------------------------------------------
echo.

set "AI_API_KEY="
set "USER_KEY="
if exist "!PROV_FILE!" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "API_KEY=" "!PROV_FILE!" 2^>nul') do set "AI_API_KEY=%%b"
)
if "!AI_API_KEY!"=="" (
    for /f "tokens=*" %%k in ('docker exec pocketclaw sh -c "echo $OPENAI_API_KEY" 2^>nul') do set "AI_API_KEY=%%k"
)
if "!AI_API_KEY!"=="not-configured-yet" set "AI_API_KEY="
if "!AI_API_KEY!"=="" (
    echo   [提示] 未检测到已配置的 API Key
    echo.
    echo   请输入 API Key 以启用 AI 分析（支持 OpenAI 兼容 API）
    echo   获取免费 Key: https://cloud.siliconflow.cn
    echo   （直接按回车跳过 AI 分析）
    echo.
    set /p "USER_KEY=  API Key: "
)
if not "!USER_KEY!"=="" set "AI_API_KEY=!USER_KEY!"
if "!AI_API_KEY!"=="" (
    echo   [跳过] 未提供 API Key，跳过 AI 分析
    set "SKIP_AI=1"
)
if "!SKIP_AI!"=="1" goto :auto_fix

echo   正在调用 AI 分析...
set "SYS_INFO=OS: Windows"
for /f "tokens=*" %%v in ('docker --version 2^>nul') do set "SYS_INFO=!SYS_INFO!, Docker: %%v"
if exist "%PROJECT_DIR%\VERSION" (
    set /p PC_VER=<"%PROJECT_DIR%\VERSION"
    set "SYS_INFO=!SYS_INFO!, Version: !PC_VER!"
)

REM 获取容器日志（保存到临时文件，避免特殊字符破坏 CMD）
set "LOG_FILE=%TEMP%\pocketclaw_doctor_logs.txt"
docker logs pocketclaw --tail 20 > "!LOG_FILE!" 2>&1

set "AI_SYS_FILE=%PROJECT_DIR%\config\doctor-system-prompt.txt"

REM 构建诊断 prompt
set "AI_PROMPT="
if not "!PROBLEMS!"=="" (
    set "AI_PROMPT=!AI_PROMPT!用户的 PocketClaw 出现故障。已检测到的问题：!PROBLEMS! 系统信息: !SYS_INFO!"
    REM 日志由 PowerShell 读取临时文件
    set "AI_PROMPT=!AI_PROMPT! 请分析故障原因并给出具体修复步骤。"
) else (
    set "AI_PROMPT=!AI_PROMPT!用户的 PocketClaw 运行一切正常。系统信息: !SYS_INFO!"
    REM 日志由 PowerShell 读取临时文件
    set "AI_PROMPT=!AI_PROMPT! 请确认系统状态良好，并给出2-3条优化建议。"
)

REM 调用 AI 分析
call :run_ai_analysis

REM ============================================
REM AI 对话模式
REM ============================================
echo.
echo   如需进一步咨询，可与 AI 继续对话
set /p "CHAT_CHOICE=  是否开启对话模式？(y/N): "
REM 对话模式下清空日志引用，避免 AI 只关注旧日志而忽略用户问题
set "LOG_FILE="
if /i not "!CHAT_CHOICE!"=="y" goto :auto_fix

:ai_chat_loop
echo.
set "USER_Q="
set /p "USER_Q=  你的问题 (输入 q 退出): "
if "!USER_Q!"=="" goto :ai_chat_done
if /i "!USER_Q!"=="q" goto :ai_chat_done
if /i "!USER_Q!"=="quit" goto :ai_chat_done
if /i "!USER_Q!"=="exit" goto :ai_chat_done

set "AI_PROMPT=用户提问: !USER_Q! 系统信息: !SYS_INFO!"
if not "!PROBLEMS!"=="" set "AI_PROMPT=!AI_PROMPT! 已检测到的问题: !PROBLEMS!"

echo   正在分析...
call :run_ai_analysis
goto :ai_chat_loop

:ai_chat_done
echo.
echo   对话结束
echo.

:auto_fix
REM ============================================
REM 工具箱（自动修复 + 常用操作）
REM ============================================
echo.
echo --------------------------------------------
echo   工具箱
echo --------------------------------------------
echo.

set "CAN_FIX=0"
set "HAS_TOKEN_ISSUE=0"

REM 检查是否有 Token 不匹配问题
set "TOKEN_LOG=%TEMP%\pocketclaw_doctor_logs.txt"
if exist "!TOKEN_LOG!" (
    findstr /i "token.mismatch" "!TOKEN_LOG!" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        set "HAS_TOKEN_ISSUE=1"
        set /a CAN_FIX+=1
        echo   [可修复] 检测到 Token 不匹配，可刷新 Token
    )
)

REM 检查可修复项: 容器已停止
for /f "tokens=*" %%c in ('docker ps -a --filter "name=pocketclaw" --filter "status=exited" --format "{{.ID}}" 2^>nul') do (
    if not "%%c"=="" (
        set /a CAN_FIX+=1
        echo   [可修复] 容器已停止，可尝试重启
    )
)

REM 检查可修复项: 磁盘空间不足
if !DISK_FREE_MB! lss 500 (
    set /a CAN_FIX+=1
    echo   [可修复] 磁盘空间不足，可清理 Docker 缓存
)

REM 检查可修复项: 镜像不存在
docker image inspect pocketclaw-pocketclaw:latest >nul 2>&1
if !ERRORLEVEL! neq 0 (
    set /a CAN_FIX+=1
    set "NEED_BUILD=1"
    echo   [可修复] 镜像不存在，可重建镜像
)

echo.
if !CAN_FIX! gtr 0 (
    echo   发现 !CAN_FIX! 个可自动修复的问题。
) else (
    echo   未发现可自动修复的问题。
)
echo.
echo   常用操作:
echo     [R] 刷新 Token（重启容器生成新 Token）
echo     [B] 重建镜像（docker-compose build）
if !CAN_FIX! gtr 0 echo     [A] 自动修复以上检测到的问题
echo     [S] 跳过
echo.
set "TOOL_CHOICE="
set /p "TOOL_CHOICE=  请选择操作 (R/B/A/S): "
if /i "!TOOL_CHOICE!"=="s" goto :export_report
if /i "!TOOL_CHOICE!"=="" goto :export_report

echo.

REM 执行 [R] 刷新 Token
if /i "!TOOL_CHOICE!"=="r" (
    echo   [修复] 正在刷新 Token（停止并重启容器）...
    docker stop pocketclaw >nul 2>&1
    timeout /t 3 /nobreak >nul
    docker start pocketclaw >nul 2>&1
    timeout /t 8 /nobreak >nul
    echo   [OK] 容器已重启，新 Token 已生成。
    echo   [提示] 请运行 PocketClaw.bat 查看新 Token。
    goto :toolbox_done
)

REM 执行 [B] 重建镜像
if /i "!TOOL_CHOICE!"=="b" (
    echo   [重建] 正在重新构建镜像，请稍等...
    cd /d "!PROJECT_DIR!"
    docker-compose build --no-cache 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] 镜像重建成功。请重新启动 PocketClaw。
    ) else (
        echo   [失败] 镜像重建失败，请检查网络和 Dockerfile。
    )
    goto :toolbox_done
)

REM 执行 [A] 自动修复
if /i not "!TOOL_CHOICE!"=="a" goto :toolbox_done
echo.

REM 执行修复: 重启容器
for /f "tokens=*" %%c in ('docker ps -a --filter "name=pocketclaw" --filter "status=exited" --format "{{.ID}}" 2^>nul') do (
    if not "%%c"=="" (
        echo   [修复] 正在重启容器...
        docker restart pocketclaw >nul 2>&1
        timeout /t 5 /nobreak >nul
        curl.exe -sf --connect-timeout 5 http://127.0.0.1:18789/health >nul 2>&1
        if !ERRORLEVEL! equ 0 (
            echo   [OK] 容器重启成功，服务已恢复
        ) else (
            echo   [警告] 容器已重启，请等待 30 秒后重新运行 doctor
        )
    )
)

REM 执行修复: 清理 Docker 缓存
if !DISK_FREE_MB! lss 500 (
    echo   [修复] 正在清理 Docker 缓存...
    docker system prune -f >nul 2>&1
    echo   [OK] Docker 缓存已清理
)

echo.
echo   修复完成。建议重新运行 doctor 确认结果。

:toolbox_done

:export_report
REM ============================================
REM 导出诊断报告
REM ============================================
echo.
echo --------------------------------------------
echo   导出诊断报告
echo --------------------------------------------

if not exist "%PROJECT_DIR%\data\logs" mkdir "%PROJECT_DIR%\data\logs"

call :write_report
if !ERRORLEVEL! neq 0 (
    echo   [警告] 报告保存失败
)

echo.
echo ============================================
echo   诊断结束
echo ============================================
echo.
pause
endlocal
exit /b 0

REM ============================================================
REM  子程序区（在主流程 exit /b 之后，防止 fall-through）
REM ============================================================

:run_ai_analysis
REM 调用 AI API（单行 PowerShell，无续行符）
set "AI_RESP_FILE=%TEMP%\pocketclaw_ai_resp.txt"
powershell -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('AI_PROMPT','Process');$lf=[Environment]::GetEnvironmentVariable('LOG_FILE','Process');if($lf -and(Test-Path $lf)){$lg=[IO.File]::ReadAllText($lf);$p=$p+' 最新日志: '+$lg};$k=[Environment]::GetEnvironmentVariable('AI_API_KEY','Process');$sf=[Environment]::GetEnvironmentVariable('AI_SYS_FILE','Process');$s=$(if($sf -and(Test-Path $sf)){[IO.File]::ReadAllText($sf,[Text.Encoding]::UTF8)}else{'PocketClaw support'});$o=[Environment]::GetEnvironmentVariable('TEMP','Process')+'\pocketclaw_ai_resp.txt';$b=@{model='qwen3-coder-plus';messages=@(@{role='system';content=$s},@{role='user';content=$p});max_tokens=2000;temperature=0.3}|ConvertTo-Json -Depth 3 -Compress;$h=@{'Authorization'='Bearer '+$k;'Content-Type'='application/json'};try{$r=Invoke-RestMethod -Uri 'https://apis.iflow.cn/v1/chat/completions' -Method POST -Headers $h -Body([System.Text.Encoding]::UTF8.GetBytes($b)) -TimeoutSec 30;[IO.File]::WriteAllText($o,$r.choices[0].message.content,[Text.Encoding]::GetEncoding(936))}catch{[IO.File]::WriteAllText($o,'AI 分析暂时不可用',[Text.Encoding]::GetEncoding(936))}"

if exist "!AI_RESP_FILE!" (
    echo.
    echo   --- AI 分析结果 ---
    echo.
    for /f "usebackq delims=" %%l in ("!AI_RESP_FILE!") do echo   %%l
    echo.
    echo   ------------------
    del /q "!AI_RESP_FILE!" 2>nul
) else (
    echo   [警告] AI 分析调用失败
)
goto :eof

:write_report
REM 生成诊断报告文件
for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd"') do set "RPT_DATE=%%d"
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format HHmm"') do set "RPT_TIME=%%t"
set "REPORT_FILE=%PROJECT_DIR%\data\logs\doctor-!RPT_DATE!-!RPT_TIME!.txt"

echo PocketClaw Doctor 诊断报告> "!REPORT_FILE!"
echo ==========================>> "!REPORT_FILE!"
echo 时间: !RPT_DATE! !RPT_TIME!>> "!REPORT_FILE!"
echo 版本: !PC_VERSION!>> "!REPORT_FILE!"
echo 系统: Windows>> "!REPORT_FILE!"
echo.>> "!REPORT_FILE!"
echo 诊断结果: !TOTAL! 项检查, 通过 !PASSED!, 失败 !FAILED!, 警告 !WARNINGS!>> "!REPORT_FILE!"
echo.>> "!REPORT_FILE!"
if not "!PROBLEMS!"=="" (
    echo 问题详情:>> "!REPORT_FILE!"
    echo !PROBLEMS!>> "!REPORT_FILE!"
    echo.>> "!REPORT_FILE!"
)

echo.
echo   报告已保存: !REPORT_FILE!
goto :eof
