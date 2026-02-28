@echo off
setlocal EnableDelayedExpansion
title PocketClaw 更新安装器
color 0B

REM ============================================================
REM install-update.bat  —— PocketClaw 一键更新安装器 [Windows]
REM
REM 朋友收到更新包后，解压并双击此文件即可安装。
REM 自动搜索 U 盘 → 创建回滚备份 → 安装更新 → 可选重启
REM
REM 不会覆盖: secrets/ data/ .env openclaw-src/ config/workspace/
REM ============================================================

set "INSTALLER_DIR=%~dp0"
set "PAYLOAD_DIR=%INSTALLER_DIR%_payload"

echo ============================================
echo   PocketClaw 更新安装器
echo ============================================
echo.

REM ── 显示更新信息 ──
if exist "%INSTALLER_DIR%UPDATE_INFO.txt" (
    type "%INSTALLER_DIR%UPDATE_INFO.txt"
    echo ============================================
    echo.
)

REM ── 检查 _payload 目录 ──
if not exist "!PAYLOAD_DIR!" (
    echo [错误] 未找到更新文件 (_payload 目录^)
    echo         请确保解压了完整的更新包后运行此脚本。
    echo.
    pause
    exit /b 1
)

REM ── 自动搜索 PocketClaw 安装位置 ──
set "TARGET_DIR="

REM 方法1: 检查父目录（更新包解压到 U 盘内的情况）
if exist "%INSTALLER_DIR%..\docker-compose.yml" (
    if exist "%INSTALLER_DIR%..\scripts\start.bat" (
        pushd "%INSTALLER_DIR%.."
        set "TARGET_DIR=!CD!"
        popd
        goto :found
    )
)

REM 方法2: 扫描常见 U 盘盘符 (D: ~ K:)
echo [信息] 正在搜索 PocketClaw 安装位置...
for %%d in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\PocketClaw\docker-compose.yml" (
        set "TARGET_DIR=%%d:\PocketClaw"
        echo   找到: !TARGET_DIR!
        goto :found
    )
)

REM 方法3: 手动输入
echo.
echo [警告] 未自动找到 PocketClaw 目录。
echo        请确保 U 盘已插入。
echo.
set /p "TARGET_DIR=请输入 PocketClaw 的完整路径 (如 E:\PocketClaw): "

:found
REM ── 验证目标目录 ──
if "!TARGET_DIR!"=="" (
    echo [错误] 未指定安装目录。
    pause
    exit /b 1
)

pushd "!TARGET_DIR!" 2>nul
if errorlevel 1 (
    echo [错误] 无法访问目录: !TARGET_DIR!
    pause
    exit /b 1
)
set "TARGET_DIR=!CD!"
popd

if not exist "!TARGET_DIR!\docker-compose.yml" (
    echo [错误] !TARGET_DIR! 不是有效的 PocketClaw 目录
    echo         缺少 docker-compose.yml
    pause
    exit /b 1
)

REM ── 读取版本号 ──
set "CUR_VERSION=unknown"
if exist "!TARGET_DIR!\VERSION" (
    set /p CUR_VERSION=<"!TARGET_DIR!\VERSION"
)
set "NEW_VERSION=unknown"
if exist "!PAYLOAD_DIR!\VERSION" (
    set /p NEW_VERSION=<"!PAYLOAD_DIR!\VERSION"
)

echo.
echo ============================================
echo   安装目录: !TARGET_DIR!
echo   当前版本: v!CUR_VERSION!
echo   更新至:   v!NEW_VERSION!
echo ============================================
echo.

set /p "CONFIRM=确认安装更新? (y/N): "
if /i not "!CONFIRM!"=="y" (
    echo 已取消。
    pause
    exit /b 0
)

echo.

REM ── 停止运行中的容器 ──
echo [1/4] 检查并停止运行中的容器...
docker compose -f "!TARGET_DIR!\docker-compose.yml" down 2>nul
if errorlevel 1 (
    docker-compose -f "!TARGET_DIR!\docker-compose.yml" down 2>nul
)
echo   [OK] 容器已停止（或未在运行）
echo.

REM ── 创建回滚备份 ──
echo [2/4] 创建回滚备份...
set "ROLLBACK_DIR=!TARGET_DIR!\data\_rollback_v!CUR_VERSION!"
if not exist "!ROLLBACK_DIR!" mkdir "!ROLLBACK_DIR!"

REM 备份根目录文件
for %%f in (docker-compose.yml Dockerfile.custom VERSION README.md QUICKSTART_WINDOWS.md .env.example .gitignore) do (
    if exist "!TARGET_DIR!\%%f" (
        copy /y "!TARGET_DIR!\%%f" "!ROLLBACK_DIR!\%%f" >nul 2>&1
    )
)

REM 备份注意事项.md（中文文件名单独处理）
if exist "!TARGET_DIR!\注意事项.md" (
    copy /y "!TARGET_DIR!\注意事项.md" "!ROLLBACK_DIR!\注意事项.md" >nul 2>&1
)

REM 备份 scripts 目录
if exist "!TARGET_DIR!\scripts" (
    if not exist "!ROLLBACK_DIR!\scripts" mkdir "!ROLLBACK_DIR!\scripts"
    xcopy /s /y /q "!TARGET_DIR!\scripts\*" "!ROLLBACK_DIR!\scripts\" >nul 2>&1
)

REM 备份 config/openclaw.json
if exist "!TARGET_DIR!\config\openclaw.json" (
    if not exist "!ROLLBACK_DIR!\config" mkdir "!ROLLBACK_DIR!\config"
    copy /y "!TARGET_DIR!\config\openclaw.json" "!ROLLBACK_DIR!\config\openclaw.json" >nul 2>&1
)

echo   [OK] 回滚备份已创建: data\_rollback_v!CUR_VERSION!
echo.

REM ── 安装更新文件 ──
echo [3/4] 正在安装更新...

REM 复制根目录文件（逐个复制，不动 secrets/data/.env/openclaw-src）
for %%f in ("!PAYLOAD_DIR!\*.*") do (
    set "FNAME=%%~nxf"
    REM 跳过 .env 文件
    if /i not "!FNAME!"==".env" (
        copy /y "%%f" "!TARGET_DIR!\" >nul 2>&1
    )
)

REM 复制 scripts/ 目录（完整覆盖）
if exist "!PAYLOAD_DIR!\scripts" (
    xcopy /s /y /q "!PAYLOAD_DIR!\scripts\*" "!TARGET_DIR!\scripts\" >nul 2>&1
    echo   [OK] scripts/ 已更新
)

REM 复制 config/openclaw.json（但保留 workspace/）
if exist "!PAYLOAD_DIR!\config\openclaw.json" (
    copy /y "!PAYLOAD_DIR!\config\openclaw.json" "!TARGET_DIR!\config\openclaw.json" >nul 2>&1
    echo   [OK] config/openclaw.json 已更新
)

REM 复制其他 config 根目录文件（如有）
for %%f in ("!PAYLOAD_DIR!\config\*.*") do (
    set "CFNAME=%%~nxf"
    if /i not "!CFNAME!"=="openclaw.json" (
        copy /y "%%f" "!TARGET_DIR!\config\" >nul 2>&1
    )
)

echo   [OK] 所有更新文件已安装
echo.

REM ── 完成 ──
echo [4/4] 更新完成!
echo.
echo ============================================
echo   [OK] 更新安装成功!
echo   v!CUR_VERSION! → v!NEW_VERSION!
echo ============================================
echo.
echo   回滚备份位置: !ROLLBACK_DIR!
echo   如遇问题，将备份文件复制回原目录即可回滚。
echo.

set /p "RESTART=是否立即启动 PocketClaw? (y/N): "
if /i "!RESTART!"=="y" (
    echo.
    echo [信息] 正在启动...
    call "!TARGET_DIR!\scripts\start.bat"
) else (
    echo.
    echo 下次启动: 双击 scripts\start.bat
)

echo.
pause
exit /b 0
