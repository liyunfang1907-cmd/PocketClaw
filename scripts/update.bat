@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM update.bat  —— 检查 PocketClaw 最新版本 [Windows]
REM 用法: scripts\update.bat
REM ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"

echo.
echo ======================================
echo    PocketClaw 一键更新器
echo ======================================
echo.

REM --------------- 检查 Docker ---------------
where docker >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Docker.
    popd & pause & exit /b 1
)

REM --------------- 代理设置 ---------------
set "USE_PROXY=0"
set "PROXY_ADDR="
set /p "USE_PROXY_YN=是否需要代理访问 GitHub? (y/N): "
if /i "!USE_PROXY_YN!"=="y" (
    set /p "PROXY_ADDR=代理地址 (默认 http://127.0.0.1:7897): "
    if "!PROXY_ADDR!"=="" set "PROXY_ADDR=http://127.0.0.1:7897"
    set "USE_PROXY=1"
    set "HTTP_PROXY=!PROXY_ADDR!"
    set "HTTPS_PROXY=!PROXY_ADDR!"
)

REM --------------- 更新方式 ---------------
echo [1/3] PocketClaw 通过 npm 安装, 重新构建即可获取最新版本.
echo.

REM --------------- 重建容器 ---------------
echo.
echo [2/3] 重建 Docker 容器 (--no-cache) ...
docker compose build --no-cache 2>nul || docker-compose build --no-cache 2>nul
echo   完成。

REM --------------- 重启 ---------------
echo.
set /p "RESTART=是否立即重启? (y/N): "
if /i "!RESTART!"=="y" (
    echo [3/3] 正在重启...
    docker compose down 2>nul || docker-compose down 2>nul
    docker compose up -d 2>nul || docker-compose up -d 2>nul
    echo   完成。
    echo.
    echo   PocketClaw 已更新并启动!
    echo   访问: http://localhost:18789
) else (
    echo [3/3] 跳过重启. 下次启动时将使用新版本.
)

echo.
echo ======================================
echo   更新完成!
echo ======================================

popd
pause
exit /b 0
