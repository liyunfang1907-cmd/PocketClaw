@echo off
setlocal EnableDelayedExpansion
title PocketClaw ������
color 0A

echo ============================================
echo   PocketClaw ��Я������
echo ============================================
echo.

:: ��ȡU���̷� (�ű�����Ŀ¼�ĸ�Ŀ¼)
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
set "ENC_FILE=%PROJECT_DIR%\secrets\.env.encrypted"

echo.
echo [��Ϣ] ��ĿĿ¼: %PROJECT_DIR%
echo.

:: ���� ��� Docker �Ƿ��Ѱ�װ ����
docker --version >nul 2>&1
if !ERRORLEVEL! equ 0 goto :docker_exists

:: PATH ��û�ҵ������Ĭ�ϰ�װ·���������� PATH ����δˢ�£�
if exist "C:\Program Files\Docker\Docker\Docker Desktop.exe" (
    set "PATH=C:\Program Files\Docker\Docker\resources\bin;%PATH%"
    docker --version >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo [��Ϣ] Docker �Ѱ�װ������ˢ�»���·��...
        goto :docker_exists
    )
)

:: ����Ƿ����ϴ�δ��ɵİ�װ��WSL2 ��������ɣ�
if exist "%PROJECT_DIR%\data\.wsl2_restart_pending" (
    del /q "%PROJECT_DIR%\data\.wsl2_restart_pending"
    echo [��Ϣ] WSL2 �Ѿ�����������װ Docker Desktop...
    goto :wsl_ok
)

:: Docker δ��װ�����밲װ����
echo [��Ϣ] δ��⵽ Docker��׼���Զ���װ...

:: ��ȷ�� WSL2 �����ã�Docker Desktop ���� WSL2��
wsl --status >nul 2>&1
if !ERRORLEVEL! equ 0 goto :wsl_ok
echo [��Ϣ] �������� WSL2����Ҫ����ԱȨ�ޣ�...
powershell -Command "Start-Process -Verb RunAs -Wait -FilePath 'wsl.exe' -ArgumentList '--install --no-distribution'"
:: WSL2 ���ú���Ҫ����������Ч���������ٰ�װ Docker
echo WSL2_PENDING> "%PROJECT_DIR%\data\.wsl2_restart_pending"
echo.
echo [��Ҫ] WSL2 �����ã���Ҫ�������Բ�����Ч��
echo        ���������ٴ����б��ű������Զ�������װ Docker Desktop��
echo.
pause
exit /b 0

:wsl_ok
:: ����Ƿ������߰�װ��
if exist "%PROJECT_DIR%\installers\DockerDesktopInstaller.exe" (
    echo [��Ϣ] �ҵ����ذ�װ����ʹ�����߰�װ...
    set "DOCKER_INSTALLER=%PROJECT_DIR%\installers\DockerDesktopInstaller.exe"
    goto :install_docker
)

:: �ӹ����Զ�����
echo [��Ϣ] ���ڴӹ������� Docker Desktop��Լ 600MB��...
echo        �����ĵȴ��������ٶ�ȡ��������...
echo.
if not exist "%TEMP%\PocketClaw" mkdir "%TEMP%\PocketClaw"
set "DL_TARGET=%TEMP%\PocketClaw\DockerDesktopInstaller.exe"
set "DL_URL=https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
REM ����ɵĲ���������
if exist "!DL_TARGET!" del /q "!DL_TARGET!"
echo [������] ��ʽ1: curl...
curl.exe -L --progress-bar -o "!DL_TARGET!" "!DL_URL!"
REM ��� curl ������ 0 �ֽ��ļ�Ҳ��Ϊʧ��
if exist "!DL_TARGET!" (
    for %%A in ("!DL_TARGET!") do if %%~zA lss 1000 del /q "!DL_TARGET!"
)
if not exist "!DL_TARGET!" (
    echo.
    echo [��Ϣ] curl ����ʧ�ܣ������� SSL ���������⣩���л� PowerShell ����...
    echo        �������Ҫ�����ӣ������ĵȴ�...
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '!DL_URL!' -OutFile '!DL_TARGET!' -UseBasicParsing"
)
echo.
if not exist "!DL_TARGET!" (
    echo [����] Docker Desktop ����ʧ�ܣ������������ӡ�
    echo        ��Ҳ�����ֶ����غ���� installers\ Ŀ¼:
    echo        https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
REM ��֤�����ļ���С��Docker Desktop Լ 600MB������Ӧ 100MB��
for %%A in ("!DL_TARGET!") do set "DL_SIZE=%%~zA"
if !DL_SIZE! lss 100000000 (
    echo [����] �����ļ���������!DL_SIZE! �ֽڣ���������������ԡ�
    del /q "!DL_TARGET!"
    pause
    exit /b 1
)
echo [OK] �������
set "DOCKER_INSTALLER=!DL_TARGET!"

:install_docker
echo.
echo [��Ϣ] ���ڰ�װ Docker Desktop����Ҫ����ԱȨ�ޣ�...
echo        ��װ��Լ��Ҫ 2-5 ���ӣ������ĵȴ�...
echo.
REM ��̨������װ��ǰ̨��ʾ����
if exist "%TEMP%\docker_install_done.tmp" del /q "%TEMP%\docker_install_done.tmp"
start /b cmd /c ""!DOCKER_INSTALLER!" install --quiet --accept-license && echo DONE > "%TEMP%\docker_install_done.tmp" || echo FAIL > "%TEMP%\docker_install_done.tmp""
set "INST_SEC=0"
set "INST_MAX=300"
<nul set /p "=  ��װ�� ["

:install_wait
if exist "%TEMP%\docker_install_done.tmp" goto :install_check
set /a "INST_SEC+=5"
if !INST_SEC! geq !INST_MAX! (
    echo ]
    echo [����] Docker ��װ��ʱ������ 5 ���ӣ���
    pause
    exit /b 1
)
set /a "INST_PCT=INST_SEC*100/INST_MAX"
title PocketClaw - ��װ Docker !INST_PCT!%% (!INST_SEC!��)
<nul set /p "=��"
timeout /t 5 /nobreak >nul
goto :install_wait

:install_check
echo ]
set /p INST_RESULT=<"%TEMP%\docker_install_done.tmp"
del /q "%TEMP%\docker_install_done.tmp" 2>nul
title PocketClaw ������
if "!INST_RESULT!"=="FAIL" (
    echo [����] Docker Desktop ��װʧ�ܣ�
    echo        ���ֶ���װ: https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
echo [OK] Docker Desktop ��װ��ɣ�
echo.
:: ������ʱ�����ļ�
if exist "%TEMP%\PocketClaw\DockerDesktopInstaller.exe" del /q "%TEMP%\PocketClaw\DockerDesktopInstaller.exe"
:: �� Docker ���뵱ǰ�Ự PATH
set "PATH=C:\Program Files\Docker\Docker\resources\bin;%PATH%"
:: �������� Docker Desktop ������ֱ��Ҫ������
echo [��Ϣ] �������� Docker Desktop���״��������ܽ�����...
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo.
set "FIRST_WAIT=0"
<nul set /p "=  �״����� ["

:first_start_wait
timeout /t 5 /nobreak >nul
set /a "FIRST_WAIT+=5"
docker info >nul 2>&1
if !ERRORLEVEL! equ 0 goto :first_start_ok
if !FIRST_WAIT! geq 180 (
    echo ]
    echo.
    echo [��ʾ] Docker Desktop �״�������Ҫ����ʱ�䡣
    echo        ���������Ժ��ٴ����б��ű���
    echo.
    pause
    exit /b 0
)
set /a "FW_PCT=FIRST_WAIT*100/180"
title PocketClaw - �״����� Docker !FW_PCT!%% ^(!FIRST_WAIT!��^)
<nul set /p "=��"
goto :first_start_wait

:first_start_ok
echo ]
echo [OK] Docker Desktop �Ѿ�����
title PocketClaw ������
goto :docker_running

:: ���� Docker �Ѱ�װ������Ƿ��������� ����
:docker_exists
docker info >nul 2>&1
if !ERRORLEVEL! equ 0 goto :docker_running

echo [��Ϣ] Docker Desktop δ���У������Զ�����...
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo.
set "WAIT_COUNT=0"
<nul set /p "=  ���� Docker ["

:wait_docker
timeout /t 5 /nobreak >nul
set /a "WAIT_COUNT+=5"
docker info >nul 2>&1
if !ERRORLEVEL! equ 0 goto :docker_started
if !WAIT_COUNT! geq 120 (
    echo ]
    echo [����] Docker Desktop ������ʱ��
    echo        ���ֶ����� Docker Desktop �����ԡ�
    pause
    exit /b 1
)
set /a "W_PCT=WAIT_COUNT*100/120"
title PocketClaw - ���� Docker !W_PCT!%% (!WAIT_COUNT!��)
<nul set /p "=��"
goto :wait_docker

:docker_started
echo ]
title PocketClaw ������
echo [OK] Docker Desktop ���Զ�����

:docker_running
echo [OK] Docker �Ѿ���
echo.

:: ���� ����ȷ����������������ã����ڱ��裩����
echo [��Ϣ] ��龵�����������...
powershell -NoProfile -Command "$f=\"$env:USERPROFILE\.docker\daemon.json\"; if((Test-Path $f) -and ((Get-Content $f -Raw) -match 'registry-mirrors')){exit 0}else{exit 1}"
if !ERRORLEVEL! equ 0 goto :mirrors_ok

echo [��Ϣ] δ��⵽����������������Զ����ã����ڼ��� Docker ���أ�...
set "MIRROR_PS1=%TEMP%\pc_mirror.ps1"
echo $f = Join-Path $env:USERPROFILE '.docker\daemon.json' > "!MIRROR_PS1!"
echo $d = Split-Path $f >> "!MIRROR_PS1!"
echo if(!(Test-Path $d)){New-Item $d -ItemType Directory -Force ^| Out-Null} >> "!MIRROR_PS1!"
echo $j = '{}' >> "!MIRROR_PS1!"
echo if(Test-Path $f){$j = Get-Content $f -Raw} >> "!MIRROR_PS1!"
echo try{$o = $j ^| ConvertFrom-Json}catch{$o = New-Object PSObject} >> "!MIRROR_PS1!"
echo $m = @('https://docker.1ms.run','https://docker.xuanyuan.me','https://mirror.ccs.tencentyun.com') >> "!MIRROR_PS1!"
echo $o ^| Add-Member -NotePropertyName 'registry-mirrors' -NotePropertyValue $m -Force >> "!MIRROR_PS1!"
echo $o ^| ConvertTo-Json -Depth 10 ^| Set-Content $f -Encoding UTF8 >> "!MIRROR_PS1!"
powershell -NoProfile -ExecutionPolicy Bypass -File "!MIRROR_PS1!"
if !ERRORLEVEL! equ 0 (
    echo [OK] ���������������
) else (
    echo [����] �������������ʧ�ܣ������Լ���...
)
del "!MIRROR_PS1!" 2>nul
echo [��Ϣ] �������� Docker Desktop ��Ӧ�ü�����...
powershell -NoProfile -Command "Get-Process -Name 'Docker Desktop','com.docker.backend','com.docker.build','docker-sandbox' -ErrorAction SilentlyContinue | Stop-Process -Force"
timeout /t 3 /nobreak >nul
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo.
set "WAIT_MIRROR=0"
<nul set /p "=  ���� Docker ["

:wait_mirror_restart
timeout /t 5 /nobreak >nul
set /a "WAIT_MIRROR+=5"
docker info >nul 2>&1
if !ERRORLEVEL! equ 0 goto :mirror_restart_done
if !WAIT_MIRROR! geq 120 (
    echo ]
    echo [����] Docker Desktop ������ʱ�����ֶ����������ԡ�
    pause
    exit /b 1
)
set /a "MR_PCT=WAIT_MIRROR*100/120"
title PocketClaw - ���� Docker !MR_PCT!%% (!WAIT_MIRROR!��)
<nul set /p "=��"
goto :wait_mirror_restart

:mirror_restart_done
echo ]
title PocketClaw ������
echo [OK] Docker ���������������������Ч

:mirrors_ok
echo.

:: ���� ȷ�� openssl ���ã�Git for Windows �Դ�������
where openssl >nul 2>&1
if !ERRORLEVEL! neq 0 (
    if exist "C:\Program Files\Git\usr\bin\openssl.exe" (
        set "PATH=C:\Program Files\Git\usr\bin;%PATH%"
    )
)

:: ���� ��� .env �ļ� ����
if exist "%PROJECT_DIR%\.env" goto :env_ready
if exist "!ENC_FILE!" goto :decrypt_env
goto :first_setup

:decrypt_env
echo [��Ϣ] ��⵽�������ã����ڽ���...
echo.
:decrypt_retry
REM ʹ�� PowerShell ��ȡ���루����ʱ��ʾ * ���ڱΣ�
for /f "delims=" %%p in ('powershell -NoProfile -Command "$p = Read-Host -Prompt '  Master Password' -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))"') do set "MASTER_PASS=%%p"
if "!MASTER_PASS!"=="" (
    echo [����] ���벻��Ϊ�գ����������롣
    echo.
    goto :decrypt_retry
)
REM ͨ�� stdin �������룬���� -pass pass: �ڽ����б���й¶
<nul set /p ="!MASTER_PASS!"| openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 ^
    -in "!ENC_FILE!" ^
    -out "%PROJECT_DIR%\.env" ^
    -pass stdin 2>nul
if !ERRORLEVEL! neq 0 (
    echo [����] ����ʧ�ܣ�������ܲ���ȷ�����������롣
    if exist "%PROJECT_DIR%\.env" del /q "%PROJECT_DIR%\.env"
    echo.
    goto :decrypt_retry
)
echo [OK] ���ܳɹ�
goto :env_ready

:first_setup
echo [����] δ�ҵ� .env �����ļ���
echo        ���������״�������...
echo.
call "%PROJECT_DIR%\scripts\setup-env.bat"
if not exist "%PROJECT_DIR%\.env" (
    if exist "!ENC_FILE!" goto :decrypt_env
    echo [����] ����δ��ɣ��޷�������
    pause
    exit /b 1
)

:env_ready
echo [OK] �����ļ�����
echo.

:: ���� ��� .env ���ڵ���δ���ܣ���ʾ���� Master Password ����
if not exist "!ENC_FILE!" (
    echo [��Ϣ] ��⵽δ���ܵ������ļ���
    echo        Ϊ�˱������ API Key���������� Master Password��
    echo.
    set /p "ENCRYPT_NOW=  �Ƿ���������������ܣ�(Y/n): "
    if /i not "!ENCRYPT_NOW!"=="n" (
        call "%PROJECT_DIR%\scripts\encrypt.bat"
        if exist "!ENC_FILE!" (
            echo [OK] ������ɣ�
        )
    ) else (
        echo [��Ϣ] ���������ܣ������ļ��������ı�����U���ϡ�
    )
    echo.
)

:: ���� ��������������� ����
if not defined GATEWAY_AUTH_PASSWORD (
    for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "-join (1..32 | ForEach-Object { [char[]]'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' | Get-Random })"`) do set "GATEWAY_AUTH_PASSWORD=%%t"
    if not defined GATEWAY_AUTH_PASSWORD set "GATEWAY_AUTH_PASSWORD=pc%RANDOM%%RANDOM%%RANDOM%%RANDOM%"
)

echo [��Ϣ] ���ڼ�� Docker Hub ��ͨ��...
curl -s --connect-timeout 5 --max-time 10 https://registry-1.docker.io/v2/ >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo [OK] Docker Hub ��������
) else (
    echo [����] Docker Hub ���ɴ����������������ã������Լ�����
)
echo.

:: ���� �������������� ����
:: �������� ���ܹ������������ؼ��ļ��Ƿ�仯����������
set "BUILD_HASH_FILE=%PROJECT_DIR%\data\.build_hash"
set "NEED_BUILD=1"

REM �� PowerShell ����ؼ��ļ�����Ϲ�ϣ
set "CURRENT_HASH="
for /f "usebackq delims=" %%h in (`powershell -NoProfile -Command "try { $files=@('%PROJECT_DIR%\Dockerfile.custom','%PROJECT_DIR%\scripts\entrypoint.sh','%PROJECT_DIR%\config\mobile.html','%PROJECT_DIR%\config\openclaw.json','%PROJECT_DIR%\VERSION'); $hasher=[System.Security.Cryptography.SHA256]::Create(); $all=[byte[]]@(); foreach($f in $files){if(Test-Path $f){$all+=[IO.File]::ReadAllBytes($f)}}; $hash=$hasher.ComputeHash($all); -join($hash|ForEach-Object{$_.ToString('x2')}) } catch { '' }"`) do set "CURRENT_HASH=%%h"

REM ��ȡ�ϴι�����ϣ
set "PREV_HASH="
if exist "!BUILD_HASH_FILE!" (
    set /p PREV_HASH=<"!BUILD_HASH_FILE!"
)

REM �ȽϹ�ϣ + ��龵���Ƿ����
if "!CURRENT_HASH!" neq "" if "!CURRENT_HASH!"=="!PREV_HASH!" (
    docker image inspect pocketclaw-pocketclaw:latest >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        set "NEED_BUILD=0"
        echo [OK] ����δ�仯�������������뼶������
    )
)

if "!NEED_BUILD!"=="0" goto :skip_build

echo [��Ϣ] ���ڹ��������� PocketClaw ����...
echo        �״ι���������������Լ��3-5���ӡ�֮���������뼶��ɡ�
echo        ��ϸ��־������: data\logs\build.log
echo.
if not exist "%PROJECT_DIR%\data\logs" mkdir "%PROJECT_DIR%\data\logs"

REM 预拉基础镜像（通过镜像加速器，避免构建时卡住）
docker image inspect node:22.16-slim >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo [信息] 预拉基础镜像 node:22.16-slim ...
    powershell -NoProfile -Command "Start-Process docker -ArgumentList 'pull','node:22.16-slim' -NoNewWindow -Wait -PassThru | ForEach-Object { if($_.ExitCode -ne 0) { exit 1 } }" >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        echo [信息] Docker Hub 拉取超时，尝试阿里云镜像...
        docker pull registry.cn-hangzhou.aliyuncs.com/library/node:22.16-slim >nul 2>&1
        if !ERRORLEVEL! equ 0 (
            docker tag registry.cn-hangzhou.aliyuncs.com/library/node:22.16-slim node:22.16-slim >nul 2>&1
            echo [OK] 通过阿里云镜像获取基础镜像成功
        ) else (
            echo [警告] 基础镜像拉取失败，构建可能很慢
        )
    )
)

REM 清除标记文件
if exist "%TEMP%\oc_build_done.tmp" del /q "%TEMP%\oc_build_done.tmp"

REM ��̨������������ǰĿ¼������Ŀ��Ŀ¼��ʹ�����·����������Ƕ�����⣩
start /b cmd /c "docker compose up -d --build > data\logs\build.log 2>&1 && echo DONE > %TEMP%\oc_build_done.tmp || echo FAIL > %TEMP%\oc_build_done.tmp"

REM ǰ̨��ʾ��������Ԥ�� 3 ���� = 180 �룬ÿ 5 ����£�
set "ELAPSED=0"
set "BUILD_MAX=180"
echo.
<nul set /p "=  �������� ["

:build_wait
if exist "%TEMP%\oc_build_done.tmp" goto :build_check
set /a "ELAPSED+=5"
if !ELAPSED! geq 900 (
    echo ]
    echo [����] ������ʱ������ 15 ���ӣ���������������ԡ�
    pause
    exit /b 1
)
set /a "B_PCT=ELAPSED*100/BUILD_MAX"
if !B_PCT! gtr 95 set "B_PCT=95"
title PocketClaw - ������ !B_PCT!%% (!ELAPSED!��)
<nul set /p "=��"
timeout /t 5 /nobreak >nul
goto :build_wait

:build_check
echo.
echo.
set /p BUILD_RESULT=<"%TEMP%\oc_build_done.tmp"
del /q "%TEMP%\oc_build_done.tmp" 2>nul
title PocketClaw ������

if "!BUILD_RESULT!"=="FAIL" (
    echo.
    echo [����] ��������ʧ�ܣ�
    echo.
    echo   ����ԭ��:
    echo   1. Docker Hub �޷����� �� �����þ�������������Ϸ�˵����
    echo   2. �˿� 18789 ��ռ�� �� �ر�ռ�øö˿ڵĳ���
    echo   3. ���̿ռ䲻�� �� ���� Docker ����: docker system prune
    echo.
    pause
    exit /b 1
)
REM ���湹��ָ��
if "!CURRENT_HASH!" neq "" echo !CURRENT_HASH!> "!BUILD_HASH_FILE!"

goto :container_ok
:skip_build


REM ��������ʱ��ȷ������������
echo [��Ϣ] ������������...
docker compose up -d >nul 2>&1
set "CONTAINER_WAIT=0"
:container_wait
docker exec pocketclaw echo OK >nul 2>&1
if !ERRORLEVEL! equ 0 goto :container_ok
set /a "CONTAINER_WAIT+=2"
if !CONTAINER_WAIT! geq 60 (
    echo [����] ����������ʱ������ Docker Desktop �Ƿ�����
    pause
    exit /b 1
)
timeout /t 2 /nobreak >nul
goto :container_wait
:container_ok


echo.
REM �汾�����ڸ��¼��׶ζ�ȡ��PC_VER��

:: �������� IP�������ֻ����ʣ�
set "LAN_IP="
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "try { (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1).IPv4Address.IPAddress } catch {}"`) do set "LAN_IP=%%a"
if not "!LAN_IP!"=="" (
    echo !LAN_IP!> "%PROJECT_DIR%\config\workspace\.host_ip" 2>nul
    REM .gateway_token ������ entrypoint.sh д�룬�˴������ظ�д�������ļ�����ͻ��
    REM ȷ������ǽ���� 18789 �˿ڣ������ֻ����ʣ�
    netsh advfirewall firewall show rule name="PocketClaw" >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        netsh advfirewall firewall add rule name="PocketClaw" dir=in action=allow protocol=TCP localport=18789 >nul 2>&1
    )
)

echo ============================================
echo   [OK] PocketClaw v!PC_VER! �ѳɹ�������
echo ============================================
echo.
echo   �������: http://127.0.0.1:18789/#token=!GATEWAY_AUTH_PASSWORD!
if "!LAN_IP!"=="" goto :skip_mobile
echo   �ֻ�����: http://!LAN_IP!:18789/mobile.html#token=!GATEWAY_AUTH_PASSWORD!
echo.
set "MOBILE_URL=http://!LAN_IP!:18789/mobile.html#token=!GATEWAY_AUTH_PASSWORD!"
call :gen_qr
:skip_mobile
echo.
echo   ֹͣ����: scripts\stop.bat
echo   �鿴��־: scripts\logs.bat
echo   �鿴״̬: scripts\status.bat
echo.
echo   [��ʾ] �������������ʾ���޷����ʡ���
echo          ��ȴ�Լ 10 ���ˢ��ҳ�漴��
echo ============================================
echo.

:: �ȴ����������������
echo [��Ϣ] �ȴ��������...
set "SVC_WAIT=0"
:svc_check
curl.exe -sf --connect-timeout 3 --max-time 5 -o nul http://127.0.0.1:18789/health 2>nul
if !ERRORLEVEL! equ 0 goto :svc_ready
set /a "SVC_WAIT+=2"
if !SVC_WAIT! geq 30 goto :svc_ready
timeout /t 2 /nobreak >nul
goto :svc_check
:svc_ready
start "" "http://127.0.0.1:18789/#token=!GATEWAY_AUTH_PASSWORD!"
echo.

:: ���� ��ȫ�������� .env����д��ɾ����ExFAT ���Ŭ���� ����
if exist "!ENC_FILE!" (
    echo [��ȫ] ���ڰ�ȫ������������...
    powershell -NoProfile -Command "$f='%PROJECT_DIR%\.env'; if(Test-Path $f){$s=(Get-Item $f).Length; $r=New-Object byte[] $s; [Security.Cryptography.RandomNumberGenerator]::Fill($r); [IO.File]::WriteAllBytes($f,$r)}" 2>nul
    del /q "%PROJECT_DIR%\.env" 2>nul
    echo [OK] ���������Ѱ�ȫ����
)

echo.
echo ��ʹ�رմ˴��ڣ�PocketClaw ���ں�̨�������У�
pause >nul
goto :eof


REM ====== �ӳ������������̲���ִ�е���� ======

:gen_qr
echo   [ɨ���ֻ�����]
echo.
REM ������������ qrcode ģ������
docker exec pocketclaw python3 -c "import qrcode,sys;qr=qrcode.QRCode(border=1);qr.add_data(sys.argv[1]);qr.print_ascii()" "!MOBILE_URL!" 2>nul
if !ERRORLEVEL! equ 0 goto :gen_qr_done
REM ���ˣ�д��ʱ�ű������� Python
echo import qrcode> "%TEMP%\pc_qr.py"
echo qr=qrcode.QRCode(border=1)>> "%TEMP%\pc_qr.py"
echo qr.add_data("!MOBILE_URL!")>> "%TEMP%\pc_qr.py"
echo qr.print_ascii()>> "%TEMP%\pc_qr.py"
set "QR_OK=0"
python3 "%TEMP%\pc_qr.py" 2>nul && set "QR_OK=1"
if "!QR_OK!"=="0" python "%TEMP%\pc_qr.py" 2>nul && set "QR_OK=1"
del /q "%TEMP%\pc_qr.py" 2>nul
if "!QR_OK!"=="0" echo   ɨ��ʧ�ܣ��븴���Ϸ� URL ���ֻ��������
:gen_qr_done
echo.
goto :eof

