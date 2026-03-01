@echo off
setlocal EnableDelayedExpansion
title PocketClaw AI ����
color 0A
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
set "PROJECT_DIR=%CD%"
set "ENC_FILE=%PROJECT_DIR%\secrets\.env.encrypted"
set "ENV_FILE=%PROJECT_DIR%\.env"
REM --------------- ȷ�� openssl ���� ---------------
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
echo        PocketClaw AI ���� - �������
echo   ============================================
echo.
REM ��⵱ǰ״̬
docker info >nul 2>&1
if !ERRORLEVEL! neq 0 (
    echo   [״̬] Docker δ����
) else (
    docker ps --filter "name=pocketclaw" --format "{{.Status}}" 2>nul > "%TEMP%\oc_status.tmp"
    set "OC_STATUS="
    set /p OC_STATUS=<"%TEMP%\oc_status.tmp" 2>nul
    del /q "%TEMP%\oc_status.tmp" 2>nul
    if "!OC_STATUS!"=="" (
        echo   [״̬] PocketClaw δ����
    ) else (
        echo   [״̬] PocketClaw ������ - !OC_STATUS!
        echo   [��ַ] http://127.0.0.1:18789/#token=pocketclaw
    )
)
if exist "!ENC_FILE!" (
    echo   [����] ������
) else (
    echo   [����] δ���ã���Ҫ�״����ã�
)
echo.
echo   --------------------------------------------
echo.
echo     [1]  ���� PocketClaw
echo     [2]  ֹͣ PocketClaw����U��ǰ������ֹͣ��
echo     [3]  ������ҳ��
echo     [4]  �л�ģ��/API Key
echo     [5]  ��������
echo     [0]  �˳�
echo.
echo   --------------------------------------------
set /p "CHOICE=  ��ѡ�� [0-5]: "
if "!CHOICE!"=="1" goto :do_start
if "!CHOICE!"=="2" goto :do_stop
if "!CHOICE!"=="3" goto :do_open
if "!CHOICE!"=="4" goto :do_change_api
if "!CHOICE!"=="5" goto :do_backup
if "!CHOICE!"=="0" goto :do_exit
echo.
echo   [����] ��Чѡ�����������롣
timeout /t 2 >nul
goto :menu

REM ============================================================
REM  ����
REM ============================================================
:do_start
cls
call "%PROJECT_DIR%\scripts\start.bat"
goto :menu

REM ============================================================
REM  ֹͣ
REM ============================================================
:do_stop
cls
call "%PROJECT_DIR%\scripts\stop.bat"
echo.
set /p "GO_BACK=  ���س����ز˵������� q �˳�: "
if /i "!GO_BACK!"=="q" goto :do_exit
goto :menu

REM ============================================================
REM  ��������
REM ============================================================
:do_open
start "" "http://127.0.0.1:18789/#token=pocketclaw"
timeout /t 1 >nul
goto :menu

REM ============================================================
REM  �޸� API Key
REM ============================================================
:do_change_api
cls
call "%PROJECT_DIR%\scripts\change-api.bat"
pause
goto :menu

REM ============================================================
REM  ��������
REM ============================================================
:do_backup
cls
call "%PROJECT_DIR%\scripts\backup.bat"
pause
goto :menu

REM ============================================================
REM  �˳�
REM ============================================================
:do_exit
echo.
echo   �ټ���
endlocal
