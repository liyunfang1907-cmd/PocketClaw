@echo off
setlocal EnableDelayedExpansion
title PocketClaw 启动器
color 0A

echo ============================================
echo   PocketClaw 便携启动器
echo ============================================
echo.

:: 获取U盘盘符 (脚本所在目录的父目录)
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
set "ENC_FILE=%PROJECT_DIR%\secrets\.env.encrypted"

echo.
echo [信息] 项目目录: %PROJECT_DIR%
echo.

:: ── 检查 Docker 是否已安装 ──
docker --version >nul 2>&1
if !ERRORLEVEL! equ 0 goto :docker_exists

:: Docker 未安装，进入安装流程
echo [信息] 未检测到 Docker，准备自动安装...

:: 先确保 WSL2 已启用（Docker Desktop 依赖 WSL2）
wsl --status >nul 2>&1
if !ERRORLEVEL! equ 0 goto :wsl_ok
echo [信息] 正在启用 WSL2（需要管理员权限）...
powershell -Command "Start-Process -Verb RunAs -Wait -FilePath 'wsl.exe' -ArgumentList '--install --no-distribution'"
if !ERRORLEVEL! neq 0 (
    echo [警告] WSL2 启用可能需要重启电脑。
) else (
    echo [OK] WSL2 已启用
)

:wsl_ok
:: 检查是否有离线安装包
if exist "%PROJECT_DIR%\installers\DockerDesktopInstaller.exe" (
    echo [信息] 找到本地安装包，使用离线安装...
    set "DOCKER_INSTALLER=%PROJECT_DIR%\installers\DockerDesktopInstaller.exe"
    goto :install_docker
)

:: 从官网自动下载
echo [信息] 正在从官网下载 Docker Desktop（约 600MB）...
echo        请耐心等待，下载速度取决于网络...
echo.
if not exist "%TEMP%\PocketClaw" mkdir "%TEMP%\PocketClaw"
set "DL_TARGET=%TEMP%\PocketClaw\DockerDesktopInstaller.exe"
set "DL_URL=https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
REM 清除旧的不完整下载
if exist "!DL_TARGET!" del /q "!DL_TARGET!"
echo [下载中] 方式1: curl...
curl.exe -L --progress-bar -o "!DL_TARGET!" "!DL_URL!"
REM 如果 curl 创建了 0 字节文件也视为失败
if exist "!DL_TARGET!" (
    for %%A in ("!DL_TARGET!") do if %%~zA lss 1000 del /q "!DL_TARGET!"
)
if not exist "!DL_TARGET!" (
    echo.
    echo [信息] curl 下载失败（可能是 SSL 兼容性问题），切换 PowerShell 下载...
    echo        这可能需要几分钟，请耐心等待...
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '!DL_URL!' -OutFile '!DL_TARGET!' -UseBasicParsing"
)
echo.
if not exist "!DL_TARGET!" (
    echo [错误] Docker Desktop 下载失败！请检查网络连接。
    echo        你也可以手动下载后放入 installers\ 目录:
    echo        https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
REM 验证下载文件大小（Docker Desktop 约 600MB，至少应 100MB）
for %%A in ("!DL_TARGET!") do set "DL_SIZE=%%~zA"
if !DL_SIZE! lss 100000000 (
    echo [错误] 下载文件不完整（!DL_SIZE! 字节），请检查网络后重试。
    del /q "!DL_TARGET!"
    pause
    exit /b 1
)
echo [OK] 下载完成
set "DOCKER_INSTALLER=!DL_TARGET!"

:install_docker
echo.
echo [信息] 正在安装 Docker Desktop（需要管理员权限）...
echo        安装大约需要 2-5 分钟，请耐心等待...
echo.
REM 后台启动安装，前台显示进度
if exist "%TEMP%\docker_install_done.tmp" del /q "%TEMP%\docker_install_done.tmp"
start /b cmd /c ""!DOCKER_INSTALLER!" install --quiet --accept-license && echo DONE > "%TEMP%\docker_install_done.tmp" || echo FAIL > "%TEMP%\docker_install_done.tmp""
set "INST_SEC=0"
set "INST_MAX=300"
<nul set /p "=  安装中 ["

:install_wait
if exist "%TEMP%\docker_install_done.tmp" goto :install_check
set /a "INST_SEC+=5"
if !INST_SEC! geq !INST_MAX! (
    echo ]
    echo [错误] Docker 安装超时（超过 5 分钟）！
    pause
    exit /b 1
)
set /a "INST_PCT=INST_SEC*100/INST_MAX"
title PocketClaw - 安装 Docker !INST_PCT!%% (!INST_SEC!秒)
<nul set /p "=█"
timeout /t 5 /nobreak >nul
goto :install_wait

:install_check
echo ]
set /p INST_RESULT=<"%TEMP%\docker_install_done.tmp"
del /q "%TEMP%\docker_install_done.tmp" 2>nul
title PocketClaw 启动器
if "!INST_RESULT!"=="FAIL" (
    echo [错误] Docker Desktop 安装失败！
    echo        请手动安装: https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
echo [OK] Docker Desktop 安装完成！
echo.
:: 清理临时下载文件
if exist "%TEMP%\PocketClaw\DockerDesktopInstaller.exe" del /q "%TEMP%\PocketClaw\DockerDesktopInstaller.exe"
echo [重要] 首次安装 Docker 后需要重启电脑以启用 WSL2。
echo        请重启电脑后再次运行本脚本。
echo.
pause
exit /b 0

:: ── Docker 已安装，检查是否正在运行 ──
:docker_exists
docker info >nul 2>&1
if !ERRORLEVEL! equ 0 goto :docker_running

echo [信息] Docker Desktop 未运行，正在自动启动...
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo.
set "WAIT_COUNT=0"
<nul set /p "=  启动 Docker ["

:wait_docker
timeout /t 5 /nobreak >nul
set /a "WAIT_COUNT+=5"
docker info >nul 2>&1
if !ERRORLEVEL! equ 0 goto :docker_started
if !WAIT_COUNT! geq 120 (
    echo ]
    echo [错误] Docker Desktop 启动超时！
    echo        请手动启动 Docker Desktop 后重试。
    pause
    exit /b 1
)
set /a "W_PCT=WAIT_COUNT*100/120"
title PocketClaw - 启动 Docker !W_PCT!%% (!WAIT_COUNT!秒)
<nul set /p "=█"
goto :wait_docker

:docker_started
echo ]
title PocketClaw 启动器
echo [OK] Docker Desktop 已自动启动

:docker_running
echo [OK] Docker 已就绪
echo.

:: ── 主动确保镜像加速器已配置（国内必需）──
echo [信息] 检查镜像加速器配置...
powershell -NoProfile -Command "$f=\"$env:USERPROFILE\.docker\daemon.json\"; if((Test-Path $f) -and ((Get-Content $f -Raw) -match 'registry-mirrors')){exit 0}else{exit 1}"
if !ERRORLEVEL! equ 0 goto :mirrors_ok

echo [信息] 未检测到镜像加速器，正在自动配置（国内加速 Docker 下载）...
set "MIRROR_PS1=%TEMP%\pc_mirror.ps1"
echo $f = Join-Path $env:USERPROFILE '.docker\daemon.json' > "!MIRROR_PS1!"
echo $d = Split-Path $f >> "!MIRROR_PS1!"
echo if(!(Test-Path $d)){New-Item $d -ItemType Directory -Force ^| Out-Null} >> "!MIRROR_PS1!"
echo $j = '{}' >> "!MIRROR_PS1!"
echo if(Test-Path $f){$j = Get-Content $f -Raw} >> "!MIRROR_PS1!"
echo try{$o = $j ^| ConvertFrom-Json}catch{$o = New-Object PSObject} >> "!MIRROR_PS1!"
echo $m = @('https://docker.1ms.run','https://docker.xuanyuan.me') >> "!MIRROR_PS1!"
echo $o ^| Add-Member -NotePropertyName 'registry-mirrors' -NotePropertyValue $m -Force >> "!MIRROR_PS1!"
echo $o ^| ConvertTo-Json -Depth 10 ^| Set-Content $f -Encoding UTF8 >> "!MIRROR_PS1!"
powershell -NoProfile -ExecutionPolicy Bypass -File "!MIRROR_PS1!"
if !ERRORLEVEL! equ 0 (
    echo [OK] 镜像加速器已配置
) else (
    echo [警告] 镜像加速器配置失败，将尝试继续...
)
del "!MIRROR_PS1!" 2>nul
echo [信息] 正在重启 Docker Desktop 以应用加速器...
powershell -NoProfile -Command "Get-Process -Name 'Docker Desktop','com.docker.backend','com.docker.build','docker-sandbox' -ErrorAction SilentlyContinue | Stop-Process -Force"
timeout /t 3 /nobreak >nul
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo.
set "WAIT_MIRROR=0"
<nul set /p "=  重启 Docker ["

:wait_mirror_restart
timeout /t 5 /nobreak >nul
set /a "WAIT_MIRROR+=5"
docker info >nul 2>&1
if !ERRORLEVEL! equ 0 goto :mirror_restart_done
if !WAIT_MIRROR! geq 120 (
    echo ]
    echo [错误] Docker Desktop 重启超时！请手动重启后重试。
    pause
    exit /b 1
)
set /a "MR_PCT=WAIT_MIRROR*100/120"
title PocketClaw - 重启 Docker !MR_PCT!%% (!WAIT_MIRROR!秒)
<nul set /p "=█"
goto :wait_mirror_restart

:mirror_restart_done
echo ]
title PocketClaw 启动器
echo [OK] Docker 已重启，镜像加速器已生效

:mirrors_ok
echo.

:: ── 确保 openssl 可用（Git for Windows 自带）──
where openssl >nul 2>&1
if !ERRORLEVEL! neq 0 (
    if exist "C:\Program Files\Git\usr\bin\openssl.exe" (
        set "PATH=C:\Program Files\Git\usr\bin;%PATH%"
    )
)

:: ── 检查 .env 文件 ──
if exist "%PROJECT_DIR%\.env" goto :env_ready
if exist "!ENC_FILE!" goto :decrypt_env
goto :first_setup

:decrypt_env
echo [信息] 检测到加密配置，正在解密...
echo.
REM 使用 PowerShell 读取密码（输入时显示 * 号遮蔽）
for /f "delims=" %%p in ('powershell -NoProfile -Command "$p = Read-Host -Prompt '  Master Password' -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))"') do set "MASTER_PASS=%%p"
if "!MASTER_PASS!"=="" (
    echo [错误] 密码不能为空。
    pause
    exit /b 1
)
REM 通过 stdin 传递密码，避免 -pass pass: 在进程列表中泄露
<nul set /p ="!MASTER_PASS!"| openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 ^
    -in "!ENC_FILE!" ^
    -out "%PROJECT_DIR%\.env" ^
    -pass stdin 2>nul
if !ERRORLEVEL! neq 0 (
    echo [错误] 解密失败，密码可能不正确。
    if exist "%PROJECT_DIR%\.env" del /q "%PROJECT_DIR%\.env"
    pause
    exit /b 1
)
echo [OK] 解密成功
goto :env_ready

:first_setup
echo [警告] 未找到 .env 配置文件！
echo        正在启动首次配置向导...
echo.
call "%PROJECT_DIR%\scripts\setup-env.bat"
if not exist "%PROJECT_DIR%\.env" (
    if exist "!ENC_FILE!" goto :decrypt_env
    echo [错误] 配置未完成，无法启动。
    pause
    exit /b 1
)

:env_ready
echo [OK] 配置文件就绪
echo.

:: ── 如果 .env 存在但尚未加密，提示设置 Master Password ──
if not exist "!ENC_FILE!" (
    echo [信息] 检测到未加密的配置文件。
    echo        为了保护你的 API Key，建议设置 Master Password。
    echo.
    set /p "ENCRYPT_NOW=  是否现在设置密码加密？(Y/n): "
    if /i not "!ENCRYPT_NOW!"=="n" (
        call "%PROJECT_DIR%\scripts\encrypt.bat"
        if exist "!ENC_FILE!" (
            echo [OK] 加密完成！
        )
    ) else (
        echo [信息] 已跳过加密，配置文件将以明文保存在U盘上。
    )
    echo.
)

:: ── Docker Hub 连通性检测（镜像加速器已在前面配置）──
echo [信息] 正在检测 Docker Hub 连通性...
docker pull --quiet hello-world >nul 2>&1
if !ERRORLEVEL! equ 0 goto :hub_ok

echo [警告] Docker Hub 连接测试失败，但镜像加速器已配置。
echo        将尝试继续构建，如果失败请检查网络连接。
goto :hub_done

:hub_ok
echo [OK] Docker Hub 连接正常
docker rmi hello-world >nul 2>&1

:hub_done
echo.

:: ── 构建并启动容器 ──
echo [信息] 正在构建并启动 PocketClaw 容器...
echo        首次构建大约需要 2-5 分钟，请耐心等待。
echo        详细日志保存在: data\logs\build.log
echo.
if not exist "%PROJECT_DIR%\data\logs" mkdir "%PROJECT_DIR%\data\logs"

REM 清除旧标记文件
if exist "%TEMP%\oc_build_done.tmp" del /q "%TEMP%\oc_build_done.tmp"

REM 后台启动构建（当前目录已是项目根目录，使用相对路径避免引号嵌套问题）
start /b cmd /c "docker compose up -d --build > data\logs\build.log 2>&1 && echo DONE > %TEMP%\oc_build_done.tmp || echo FAIL > %TEMP%\oc_build_done.tmp"

REM 前台显示进度条（预估 3 分钟 = 180 秒，每 5 秒更新）
set "ELAPSED=0"
set "BUILD_MAX=180"
echo.
<nul set /p "=  构建容器 ["

:build_wait
if exist "%TEMP%\oc_build_done.tmp" goto :build_check
set /a "ELAPSED+=5"
if !ELAPSED! geq 900 (
    echo ]
    echo [错误] 构建超时（超过 15 分钟），请检查网络后重试。
    pause
    exit /b 1
)
set /a "B_PCT=ELAPSED*100/BUILD_MAX"
if !B_PCT! gtr 95 set "B_PCT=95"
title PocketClaw - 构建中 !B_PCT!%% (!ELAPSED!秒)
<nul set /p "=█"
timeout /t 5 /nobreak >nul
goto :build_wait

:build_check
echo.
echo.
set /p BUILD_RESULT=<"%TEMP%\oc_build_done.tmp"
del /q "%TEMP%\oc_build_done.tmp" 2>nul
title PocketClaw 启动器

if "!BUILD_RESULT!"=="FAIL" (
    echo.
    echo [错误] 容器启动失败！
    echo.
    echo   可能原因:
    echo   1. Docker Hub 无法访问 → 请配置镜像加速器（见上方说明）
    echo   2. 端口 18789 被占用 → 关闭占用该端口的程序
    echo   3. 磁盘空间不足 → 清理 Docker 镜像: docker system prune
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   [OK] PocketClaw 已成功启动！
echo ============================================
echo.
echo   控制面板: http://127.0.0.1:18789/pocketclaw
echo.
echo   停止服务: scripts\stop.bat
echo   查看日志: scripts\logs.bat
echo   查看状态: scripts\status.bat
echo ============================================
echo.

:: 打开浏览器
echo [信息] 正在打开浏览器...
start "" "http://127.0.0.1:18789/pocketclaw"
echo.

:: ── 安全擦除明文 .env（覆写后删除，ExFAT 最佳努力） ──
if exist "!ENC_FILE!" (
    echo [安全] 正在安全擦除明文配置...
    powershell -NoProfile -Command "$f='%PROJECT_DIR%\.env'; if(Test-Path $f){$s=(Get-Item $f).Length; $r=New-Object byte[] $s; [Security.Cryptography.RandomNumberGenerator]::Fill($r); [IO.File]::WriteAllBytes($f,$r)}" 2>nul
    del /q "%PROJECT_DIR%\.env" 2>nul
    echo [OK] 明文配置已安全擦除
)

echo.
echo 即使关闭此窗口，PocketClaw 仍在后台持续运行！
pause >nul
