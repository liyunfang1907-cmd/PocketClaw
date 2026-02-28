@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM reset.bat  —— 重置 PocketClaw 到初始状态 [Windows]
REM 用法: scripts\reset.bat
REM ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"

echo.
echo ======================================
echo    PocketClaw 重置工具
echo ======================================
echo.
echo [警告] 此操作将:
echo   1. 停止并删除容器和镜像
echo   2. 删除 .env 明文和加密文件
echo   3. 删除会话数据和日志
echo   4. 删除下载的源代码
echo.
echo   config/ 目录 (openclaw.json等) 将被保留.
echo   scripts/ 目录 (脚本) 将被保留.
echo.

set /p "CONFIRM=确定要重置吗? 输入 YES 确认: "
if not "!CONFIRM!"=="YES" (
    echo 已取消.
    popd
    pause
    exit /b 0
)

echo.

REM --------------- 1. 停止容器 ---------------
echo [1/5] 停止容器...
docker compose down --rmi all --volumes 2>nul || docker-compose down --rmi all --volumes 2>nul
echo   完成。

REM --------------- 2. 删除 .env ---------------
echo [2/5] 清理敏感文件...
if exist "%PROJECT_DIR%\.env" (
    powershell -NoProfile -Command "$f='%PROJECT_DIR%\.env'; $s=(Get-Item $f).Length; $r=New-Object byte[] $s; [Security.Cryptography.RandomNumberGenerator]::Fill($r); [IO.File]::WriteAllBytes($f,$r)" 2>nul
    del /q "%PROJECT_DIR%\.env"
)
if exist "%PROJECT_DIR%\secrets\.env.encrypted" del "%PROJECT_DIR%\secrets\.env.encrypted"
if exist "%PROJECT_DIR%\config\workspace\.provider" del "%PROJECT_DIR%\config\workspace\.provider"
echo   完成。

REM --------------- 3. 删除数据 ---------------
echo [3/5] 清理数据目录...
if exist "%PROJECT_DIR%\data\sessions" rd /s /q "%PROJECT_DIR%\data\sessions" & mkdir "%PROJECT_DIR%\data\sessions"
if exist "%PROJECT_DIR%\data\logs" rd /s /q "%PROJECT_DIR%\data\logs" & mkdir "%PROJECT_DIR%\data\logs"
if exist "%PROJECT_DIR%\data\credentials" rd /s /q "%PROJECT_DIR%\data\credentials" & mkdir "%PROJECT_DIR%\data\credentials"
echo   完成。

REM --------------- 4. 删除源码 ---------------
echo [4/5] 清理源代码...
if exist "%PROJECT_DIR%\openclaw-src" rd /s /q "%PROJECT_DIR%\openclaw-src"
echo   完成。

REM --------------- 5. 保留文件清单 ---------------
echo [5/5] 已保留的文件:
echo   config\openclaw.json
echo   config\workspace\AGENTS.md
echo   config\workspace\SOUL.md
echo   scripts\*.bat / *.sh
echo   docker-compose.yml
echo   .env.example
echo   README.md

echo.
echo ======================================
echo   重置完成!
echo ======================================
echo.
echo 重新开始: 运行 scripts\setup-env.bat

popd
pause
exit /b 0
