@echo off
setlocal EnableDelayedExpansion
title PocketClaw 停止

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"

REM 提取U盘盘符（取PROJECT_DIR的前2个字符，如 G:）
set "DRIVE_LETTER=%PROJECT_DIR:~0,2%"

echo ============================================
echo   PocketClaw 停止中...
echo ============================================
echo.

:: 步骤1：停止容器（支持 docker compose v1/v2）
echo [1/6] 停止 Docker 容器...
docker compose -f "%PROJECT_DIR%\docker-compose.yml" down 2>nul || docker-compose -f "%PROJECT_DIR%\docker-compose.yml" down 2>nul
if !ERRORLEVEL! equ 0 (
    echo       容器已停止
) else (
    echo       容器可能已经停止
)
echo.

:: 步骤2：安全擦除 .env（覆写后删除，ExFAT 磁盘努力擦除）
echo [2/6] 安全擦除临时配置...
if exist "%PROJECT_DIR%\.env" (
    powershell -NoProfile -Command "$f='%PROJECT_DIR%\.env'; if(Test-Path $f){$s=(Get-Item $f).Length; $r=New-Object byte[] $s; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($r); [IO.File]::WriteAllBytes($f,$r)}" 2>nul
    del /q "%PROJECT_DIR%\.env"
    echo       明文配置已安全擦除
) else (
    echo       无需擦除
)
echo.

:: 步骤3：关闭所有 Docker 相关进程
echo [3/6] 关闭 Docker Desktop...
taskkill /F /IM "Docker Desktop.exe" >nul 2>&1
taskkill /F /IM "com.docker.backend.exe" >nul 2>&1
taskkill /F /IM "com.docker.build.exe" >nul 2>&1
taskkill /F /IM "com.docker.extensions.exe" >nul 2>&1
taskkill /F /IM "docker-sandbox.exe" >nul 2>&1
taskkill /F /IM "com.docker.dev-envs.exe" >nul 2>&1
timeout /t 2 /nobreak >nul
echo       Docker 进程已关闭
echo.

:: 步骤4：关闭打开了U盘目录的资源管理器窗口
echo [4/6] 关闭U盘相关窗口...
powershell -NoProfile -Command "& { try { $shell = New-Object -ComObject Shell.Application; $shell.Windows() | ForEach-Object { try { if ($_.LocationURL -like ('*' + '%DRIVE_LETTER%'.Substring(0,1) + '%3A*') -or $_.LocationURL -like ('*' + '%DRIVE_LETTER%'.Substring(0,1) + ':*')) { $_.Quit() } } catch {} } } catch {} }" 2>nul
echo       已处理
echo.

:: 步骤5：切离U盘目录（必须在 mountvol 之前）
echo [5/6] 切离U盘目录...
cd /d "%SystemDrive%\"
echo       工作目录已切到 %SystemDrive%\
echo.

:: 步骤6：安全弹出U盘（卸载卷）
echo [6/6] 安全弹出U盘...
set /p "EJECT_NOW=      是否弹出U盘？(Y/n): "
if /i "!EJECT_NOW!"=="n" goto :skip_eject

REM 等待文件系统刷新缓存
timeout /t 2 /nobreak >nul

REM 使用 mountvol 卸载卷（支持被识别为固定磁盘的U盘）
mountvol !DRIVE_LETTER!\ /P >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo.
    echo ============================================
    echo   U盘已安全弹出，可以拔掉了！
    echo ============================================
) else (
    echo [警告] 自动弹出失败，请手动右键托盘"安全删除硬件"
)
goto :done

:skip_eject
echo.
echo ============================================
echo   PocketClaw 已停止
echo   U盘未弹出（可继续使用）
echo ============================================

:done
echo.
pause
