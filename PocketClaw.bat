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
        echo   [状态] PocketClaw 运行中
        call :show_running_info
    )
)
if exist "!ENC_FILE!" (
    echo   [配置] 已配置
) else (
    echo   [配置] 未配置（需要首次设置）
)
echo.
echo   --------------------------------------------
echo.
echo     [1]  启动 PocketClaw
echo     [2]  停止 PocketClaw（拔U盘前请先停止）
echo     [3]  打开网页版
echo     [4]  切换模型/API Key
echo     [5]  备份数据
echo     [6]  自诊断修复
echo     [7]  检查更新
echo     [0]  退出
echo.
echo   --------------------------------------------
set /p "CHOICE=  请选择 [0-7]: "
if "!CHOICE!"=="1" goto :do_start
if "!CHOICE!"=="2" goto :do_stop
if "!CHOICE!"=="3" goto :do_open
if "!CHOICE!"=="4" goto :do_change_api
if "!CHOICE!"=="5" goto :do_backup
if "!CHOICE!"=="6" goto :do_doctor
if "!CHOICE!"=="7" goto :do_update
if "!CHOICE!"=="0" goto :do_exit
echo.
echo   [提示] 无效选择，请重新输入。
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
set /p "GO_BACK=  按回车键返回菜单，输入 q 退出: "
if /i "!GO_BACK!"=="q" goto :do_exit
goto :menu

REM ============================================================
REM  打开网页版
REM ============================================================
:do_open
set "GW_TOKEN="
if exist "%PROJECT_DIR%\config\workspace\.gateway_token" (
    set /p GW_TOKEN=<"%PROJECT_DIR%\config\workspace\.gateway_token"
)
if "!GW_TOKEN!"=="" set "GW_TOKEN=pocketclaw"
start "" "http://127.0.0.1:18789/#token=!GW_TOKEN!"
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
REM  备份数据
REM ============================================================
:do_backup
cls
call "%PROJECT_DIR%\scripts\backup.bat"
pause
goto :menu

REM ============================================================
REM  自诊断修复
REM ============================================================
:do_doctor
cls
call "%PROJECT_DIR%\scripts\doctor.bat"
echo.
set /p "GO_BACK=  按回车键返回菜单，输入 q 退出: "
if /i "!GO_BACK!"=="q" goto :do_exit
goto :menu

REM ============================================================
REM  检查更新
REM ============================================================
:do_update
cls
call "%PROJECT_DIR%\scripts\update.bat"
echo.
set /p "GO_BACK=  按回车键返回菜单，输入 q 退出: "
if /i "!GO_BACK!"=="q" goto :do_exit
goto :menu

REM ============================================================
REM  检查更新
REM ============================================================
:do_update
cls
call "%PROJECT_DIR%\scripts\update.bat"
echo.
set /p "GO_BACK=  按回车键返回菜单，输入 q 退出: "
if /i "!GO_BACK!"=="q" goto :do_exit
goto :menu

REM ============================================================
REM  退出
REM ============================================================
:do_exit
echo.
echo   再见！
endlocal

goto :eof

REM ============================================================
REM  子程序: 显示运行状态 (提供商/模型/健康检查/可切换API)
REM ============================================================
:show_running_info
set "MENU_TOKEN="
if exist "%PROJECT_DIR%\config\workspace\.gateway_token" set /p MENU_TOKEN=<"%PROJECT_DIR%\config\workspace\.gateway_token"
if "!MENU_TOKEN!"=="" set "MENU_TOKEN=pocketclaw"
echo   [地址] http://127.0.0.1:18789/#token=!MENU_TOKEN!

REM 读取当前提供商和模型
set "MENU_PROV="
set "MENU_MODEL="
if not exist "%PROJECT_DIR%\config\workspace\.provider" goto :skip_provider
for /f "tokens=2 delims==" %%v in ('findstr /i "^PROVIDER_NAME=" "%PROJECT_DIR%\config\workspace\.provider"') do set "MENU_PROV=%%v"
for /f "tokens=2 delims==" %%v in ('findstr /i "^MODEL_ID=" "%PROJECT_DIR%\config\workspace\.provider"') do set "MENU_MODEL=%%v"
:skip_provider

REM API 健康检查
set "HEALTH_OK=0"
curl.exe -sf --connect-timeout 2 --max-time 3 -o nul http://127.0.0.1:18789/health 2>nul
if !ERRORLEVEL! equ 0 set "HEALTH_OK=1"

REM 显示第一行: [模型] provider / model + 健康状态
if defined MENU_PROV (
    if "!HEALTH_OK!"=="1" (
        echo   [模型] !MENU_PROV! / !MENU_MODEL!  [可用]
    ) else (
        echo   [模型] !MENU_PROV! / !MENU_MODEL!  [异常]
    )
) else (
    if "!HEALTH_OK!"=="1" (
        echo   [API]  已连接
    ) else (
        echo   [API]  连接异常
    )
)

REM 显示第二行: 可切换的已绑定 API
set "BOUND_LIST="
if not exist "%PROJECT_DIR%\config\workspace\.bound_providers" goto :skip_bound
for /f "usebackq delims=" %%p in ("%PROJECT_DIR%\config\workspace\.bound_providers") do (
    if not "%%p"=="!MENU_PROV!" (
        if defined BOUND_LIST (
            set "BOUND_LIST=!BOUND_LIST!, %%p"
        ) else (
            set "BOUND_LIST=%%p"
        )
    )
)
:skip_bound
if defined BOUND_LIST (
    echo          可切换: !BOUND_LIST!
)

goto :eof
