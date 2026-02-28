@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM backup.bat  —— 将 PocketClaw 关键文件备份到本地 [Windows]
REM 默认备份路径: %USERPROFILE%\PocketClaw_Backup\
REM 用法: scripts\backup.bat [target_dir]
REM ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"

REM 备份目标
if "%~1"=="" (
    set "BACKUP_DIR=%USERPROFILE%\PocketClaw_Backup"
) else (
    set "BACKUP_DIR=%~1"
)

REM 时间戳 (优先 wmic，降级 PowerShell)
set "DT="
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value 2^>nul') do set "DT=%%i"
if "!DT!"=="" (
    for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMddHHmmss'"') do set "DT=%%t"
)
set "SNAPSHOT_DIR=%BACKUP_DIR%\snapshot_%DT:~0,8%_%DT:~8,4%"

echo.
echo === PocketClaw 备份工具 ===
echo 源目录: %PROJECT_DIR%
echo 备份到: %SNAPSHOT_DIR%
echo.

REM --------------- 创建目录 ---------------
if not exist "%SNAPSHOT_DIR%" mkdir "%SNAPSHOT_DIR%"

REM --------------- 备份核心文件 ---------------
echo [1/3] 备份核心文件...

REM 目录
for %%D in (config secrets scripts frontend) do (
    if exist "%PROJECT_DIR%\%%D" (
        xcopy /E /I /Q "%PROJECT_DIR%\%%D" "%SNAPSHOT_DIR%\%%D" >nul 2>&1
        echo   + %%D\
    ) else (
        echo   - %%D\ ^(不存在, 跳过^)
    )
)

REM 文件
for %%F in (docker-compose.yml Dockerfile.custom .env.example .gitignore README.md VERSION LICENSE.md PocketClaw.bat PocketClaw.command) do (
    if exist "%PROJECT_DIR%\%%F" (
        copy /Y "%PROJECT_DIR%\%%F" "%SNAPSHOT_DIR%\%%F" >nul 2>&1
        echo   + %%F
    ) else (
        echo   - %%F ^(不存在, 跳过^)
    )
)

echo.
echo [2/3] 备份可选数据...
for %%D in (data\credentials data\sessions) do (
    if exist "%PROJECT_DIR%\%%D" (
        if not exist "%SNAPSHOT_DIR%\%%D" mkdir "%SNAPSHOT_DIR%\%%D"
        xcopy /E /I /Q "%PROJECT_DIR%\%%D" "%SNAPSHOT_DIR%\%%D" >nul 2>&1
        echo   + %%D\
    ) else (
        echo   - %%D\ ^(不存在, 跳过^)
    )
)

echo.
echo [3/3] 生成备份清单...
dir /s /b "%SNAPSHOT_DIR%" > "%SNAPSHOT_DIR%\MANIFEST.txt" 2>nul

echo.
echo === 备份完成 ===
echo   路径: %SNAPSHOT_DIR%

REM 同步 README 到备份根目录
if exist "%PROJECT_DIR%\README.md" (
    copy /Y "%PROJECT_DIR%\README.md" "%BACKUP_DIR%\README.md" >nul 2>&1
)

echo.
echo [完成] 全部完成!

popd
pause
exit /b 0
