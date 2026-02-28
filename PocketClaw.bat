@echo off

setlocal EnableDelayedExpansion

title PocketClaw AI 助手

color 0A



set "SCRIPT_DIR=%~dp0"

cd /d "%SCRIPT_DIR%"

set "PROJECT_DIR=%CD%"

set "ENC_FILE=%PROJECT_DIR%\secrets\.env.encrypted"

set "ENV_FILE=%PROJECT_DIR%\.env"



REM --------------- 确保 openssl 可用 ---------------

where openssl >nul 2>&1

if errorlevel 1 (

    if exist "C:\Program Files\Git\usr\bin\openssl.exe" (

        set "PATH=C:\Program Files\Git\usr\bin;%PATH%"

    )

)



:menu

cls

echo.

echo   ============================================

echo        PocketClaw AI 助手 - 控制面板

echo   ============================================

echo.



REM 检测当前状态

docker info >nul 2>&1

if !ERRORLEVEL! neq 0 (

    echo   [状态] Docker 未运行

) else (

    docker ps --filter "name=pocketclaw" --format "{{.Status}}" 2>nul > "%TEMP%\oc_status.tmp"

    set "OC_STATUS="

    set /p OC_STATUS=<"%TEMP%\oc_status.tmp" 2>nul

    del /q "%TEMP%\oc_status.tmp" 2>nul

    if "!OC_STATUS!"=="" (

        echo   [状态] PocketClaw 未启动

    ) else (

        echo   [状态] PocketClaw 运行中 - !OC_STATUS!

        echo   [地址] http://127.0.0.1:18789/#token=pocketclaw

    )

)



if exist "!ENC_FILE!" (

    echo   [加密] 已配置

) else (

    echo   [加密] 未配置（需要首次设置）

)

echo.

echo   --------------------------------------------

echo.

echo     [1]  启动 PocketClaw

echo     [2]  停止 PocketClaw（拔U盘前必须先停止）

echo     [3]  打开聊天页面

echo     [4]  切换模型/API Key

echo     [5]  查看状态/日志

echo     [6]  备份数据

echo     [0]  退出

echo.

echo   --------------------------------------------

set /p "CHOICE=  请选择 [0-6]: "



if "!CHOICE!"=="1" goto :do_start

if "!CHOICE!"=="2" goto :do_stop

if "!CHOICE!"=="3" goto :do_open

if "!CHOICE!"=="4" goto :do_change_api

if "!CHOICE!"=="5" goto :do_status

if "!CHOICE!"=="6" goto :do_backup

if "!CHOICE!"=="0" goto :do_exit



echo.

echo   [错误] 无效选择，请重新输入。

timeout /t 2 >nul

goto :menu



REM ============================================================

REM  启动

REM ============================================================

:do_start

cls

call "%PROJECT_DIR%\scripts\start.bat"

goto :menu



REM ============================================================

REM  停止

REM ============================================================

:do_stop

cls

call "%PROJECT_DIR%\scripts\stop.bat"

echo.

set /p "GO_BACK=  按回车返回菜单，输入 q 退出: "

if /i "!GO_BACK!"=="q" goto :do_exit

goto :menu



REM ============================================================

REM  打开浏览器

REM ============================================================

:do_open

start "" "http://127.0.0.1:18789/#token=pocketclaw"

timeout /t 1 >nul

goto :menu



REM ============================================================

REM  修改 API Key

REM ============================================================

:do_change_api

cls

call "%PROJECT_DIR%\scripts\change-api.bat"

pause

goto :menu



REM ============================================================

REM  查看状态/日志

REM ============================================================

:do_status

cls

echo.

echo ======================================

echo    PocketClaw 状态和日志

echo ======================================

echo.



REM --- Docker 状态 ---

docker info >nul 2>&1

if !ERRORLEVEL! neq 0 (

    echo   [Docker] 未运行

    echo.

    goto :status_logs

)



echo   [Docker] 运行中

echo.



REM --- 容器状态 ---

echo [容器状态]

docker compose ps 2>nul

echo.



REM --- 资源使用 ---

for /f "tokens=*" %%i in ('docker compose ps -q 2^>nul') do (

    if not "%%i"=="" (

        echo [资源使用]

        docker stats --no-stream --format "  CPU: {{.CPUPerc}}  内存: {{.MemUsage}}  网络: {{.NetIO}}" %%i 2>nul

        echo.

    )

)



REM --- 端口检测 ---

echo [网络端口]

netstat -an 2>nul | findstr ":18789" >nul 2>&1

if not !ERRORLEVEL! equ 0 (

    echo   Gateway (18789): 未监听

) else (

    echo   Gateway (18789): 已监听

    echo   访问地址: http://127.0.0.1:18789/#token=pocketclaw

)

echo.



:status_logs

echo ======================================

echo    最新日志 (最近 30 行)

echo ======================================

echo.

docker compose logs --tail=30 2>nul

echo.

pause

goto :menu



REM ============================================================

REM  备份数据

REM ============================================================

:do_backup

cls

call "%PROJECT_DIR%\scripts\backup.bat"

pause

goto :menu



REM ============================================================

REM  退出

REM ============================================================

:do_exit

echo.

echo   再见！

endlocal

