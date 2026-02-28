@echo off
setlocal EnableDelayedExpansion
title PocketClaw 停止

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"

echo ============================================
echo   PocketClaw 停止中...
echo ============================================
echo.

:: 停止容器（兼容 docker compose v1/v2）
docker compose -f "%PROJECT_DIR%\docker-compose.yml" down 2>nul || docker-compose -f "%PROJECT_DIR%\docker-compose.yml" down 2>nul

if !ERRORLEVEL! neq 0 (
    echo [警告] 容器停止可能有问题，或已经停止。
)

:: 安全擦除明文 .env（覆写后删除，ExFAT 最佳努力）
if exist "%PROJECT_DIR%\.env" (
    powershell -NoProfile -Command "$f='%PROJECT_DIR%\.env'; if(Test-Path $f){$s=(Get-Item $f).Length; $r=New-Object byte[] $s; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($r); [IO.File]::WriteAllBytes($f,$r)}" 2>nul
    del /q "%PROJECT_DIR%\.env"
    echo [OK] 明文配置已安全擦除
)

echo.
echo [信息] 正在关闭 Docker Desktop（以便安全弹出U盘）...
powershell -NoProfile -Command "Get-Process -Name 'Docker Desktop','com.docker.backend','com.docker.build','com.docker.extensions' -ErrorAction SilentlyContinue | Stop-Process -Force" 2>nul
timeout /t 3 /nobreak >nul

echo.
echo [OK] PocketClaw 已停止，Docker Desktop 已关闭
echo.
echo ============================================
echo   现在可以安全弹出U盘
echo   Windows: 右键磁盘「安全删除硬件」
echo ============================================
echo.
pause
