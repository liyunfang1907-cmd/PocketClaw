@echo off
setlocal EnableDelayedExpansion
title PocketClaw 停止

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"

REM 获取U盘盘符（取PROJECT_DIR前2个字符，如 G:）
set "DRIVE_LETTER=%PROJECT_DIR:~0,2%"

echo ============================================
echo   PocketClaw 停止中...
echo ============================================
echo.

:: 步骤1：停止容器（支持 docker compose v1/v2）
echo [1/5] 停止 Docker 容器...
docker compose -f "%PROJECT_DIR%\docker-compose.yml" down 2>nul || docker-compose -f "%PROJECT_DIR%\docker-compose.yml" down 2>nul
if !ERRORLEVEL! equ 0 (
    echo       容器已停止
) else (
    echo       容器可能已经停止
)
echo.

:: 步骤2：安全擦除 .env（先覆写再删除）
echo [2/5] 安全清除临时凭证...
if exist "%PROJECT_DIR%\.env" (
    powershell -NoProfile -Command "$f='%PROJECT_DIR%\.env'; if(Test-Path $f){$s=(Get-Item $f).Length; $r=New-Object byte[] $s; [System.Security.Cryptography.RandomNumberGenerator]::Fill($r); [IO.File]::WriteAllBytes($f,$r)}" 2>nul
    del /q "%PROJECT_DIR%\.env"
    echo       临时凭证已安全擦除
) else (
    echo       无需清理
)
echo.

:: 步骤3：关闭所有 Docker 相关进程
echo [3/5] 关闭 Docker Desktop...
taskkill /F /IM "Docker Desktop.exe" >nul 2>&1
taskkill /F /IM "com.docker.backend.exe" >nul 2>&1
taskkill /F /IM "com.docker.build.exe" >nul 2>&1
taskkill /F /IM "com.docker.extensions.exe" >nul 2>&1
taskkill /F /IM "docker-sandbox.exe" >nul 2>&1
taskkill /F /IM "com.docker.dev-envs.exe" >nul 2>&1
timeout /t 2 /nobreak >nul
echo       Docker 进程已关闭
REM 删除防火墙规则
netsh advfirewall firewall delete rule name="PocketClaw" >nul 2>&1
echo.

:: 步骤4：关闭 WSL 并清理占用U盘的句柄
echo [4/5] 关闭 WSL 并释放U盘句柄...
REM 关闭 WSL 后端（Docker Desktop 使用 WSL2 引擎）
wsl --shutdown >nul 2>&1
timeout /t 2 /nobreak >nul
REM 杀掉所有可能占用U盘的 wsl/wslhost/dllhost 进程
taskkill /F /IM "wsl.exe" >nul 2>&1
taskkill /F /IM "wslhost.exe" >nul 2>&1
REM dllhost 可能是缩略图缓存
REM dllhost 不再强制结束（可能影响系统功能） >nul 2>&1
timeout /t 1 /nobreak >nul
echo       WSL 已关闭，句柄已释放
echo.

:: 步骤5：离开U盘目录
echo [5/5] 离开U盘目录...
cd /d "%SystemDrive%\"
echo       当前目录已切到 %SystemDrive%\
echo.

echo ============================================
echo   PocketClaw 已停止
echo   请通过系统托盘“安全删除硬件”弹出U盘
echo ============================================
echo.
pause


