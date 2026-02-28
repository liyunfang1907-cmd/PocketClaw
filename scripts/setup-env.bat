@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM setup-env.bat  —— 首次配置向导, 生成 .env 文件 [Windows]
REM 用法: scripts\setup-env.bat
REM ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"

set "ENV_FILE=%PROJECT_DIR%\.env"

REM --------------- 检查 .env ---------------
if exist "%ENV_FILE%" (
    echo [警告] .env 文件已存在.
    set /p "CONFIRM=是否覆盖? (y/N): "
    if /i not "!CONFIRM!"=="y" (
        echo 已取消.
        popd
        pause
        exit /b 0
    )
)

echo.
echo ===================================================
echo       PocketClaw 首次配置向导
echo       只需 2 步即可完成！
echo ===================================================
echo.

REM ==========================================
REM 1. GLM-4.7-Flash API Key
REM ==========================================
echo -- [第 1 步] 获取免费的 AI 模型 API Key --
echo.
echo   PocketClaw 使用智谱 GLM-4.7-Flash 模型（完全免费）
echo.
echo   +---------------------------------------------------+
echo   ^|  获取 API Key 步骤:                               ^|
echo   ^|                                                   ^|
echo   ^|  1. 打开: https://open.bigmodel.cn                ^|
echo   ^|  2. 点击右上角「注册/登录」, 用手机号注册         ^|
echo   ^|  3. 登录后进入「API密钥」页面                     ^|
echo   ^|     (可直接访问 https://open.bigmodel.cn/usercenter/apikeys)
echo   ^|  4. 点击「创建新的 API Key」                      ^|
echo   ^|  5. 输入名称（如: openclaw）, 点击确认            ^|
echo   ^|  6. 复制生成的 API Key                            ^|
echo   +---------------------------------------------------+
echo.

:ask_key
set "GLM_KEY="
set /p "GLM_KEY=  请粘贴你的 API Key: "
if "!GLM_KEY!"=="" (
    echo   [错误] API Key 不能为空，请重新输入。
    goto ask_key
)

echo   [OK] API Key 已录入
echo.

REM 写入 .env
REM ==========================================
(
echo # ============================================
echo # PocketClaw 环境配置文件
echo # 由首次配置向导自动生成
echo # ============================================
echo.
echo # -- Docker Compose 项目名 --
echo COMPOSE_PROJECT_NAME=pocketclaw
echo.
echo # -- 默认模型 --
echo OPENCLAW_MODEL=glm-4.7-flash
echo.
echo # -- 智谱 AI (GLM-4.7-Flash 永久免费^) --
echo OPENAI_API_KEY=!GLM_KEY!
echo.
echo # -- 模型提供商 --
echo PROVIDER_NAME=zhipu
echo.
echo # -- Gateway 认证密码 --
echo GATEWAY_AUTH_PASSWORD=pocketclaw
echo.
) > "%ENV_FILE%"

echo.
echo ===================================================
echo            [OK] API Key 配置完成！
echo ===================================================
echo.

REM ==========================================
REM 2. 设置 Master Password（加密保护）
REM ==========================================
echo -- [第 2 步] 设置 Master Password（保护你的密钥）--
echo.
echo   Master Password 用于加密你的 API Key。
echo   每次启动 PocketClaw 时需要输入此密码。
echo   如果忘记密码，需要重新配置 API Key。
echo.

:ask_password
for /f "delims=" %%p in ('powershell -NoProfile -Command "$p = Read-Host -Prompt '  请输入 Master Password' -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))"') do set "MASTER_PASS=%%p"
if "!MASTER_PASS!"=="" (
    echo   [错误] 密码不能为空，请重新输入。
    goto ask_password
)

:ask_password2
for /f "delims=" %%p in ('powershell -NoProfile -Command "$p = Read-Host -Prompt '  请再次确认密码' -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))"') do set "MASTER_PASS2=%%p"
if not "!MASTER_PASS!"=="!MASTER_PASS2!" (
    echo   [错误] 两次密码不一致，请重新设置。
    goto ask_password
)

echo.
echo [信息] 正在加密配置文件...

REM 确保 openssl 可用
where openssl >nul 2>&1
if !ERRORLEVEL! neq 0 (
    if exist "C:\Program Files\Git\usr\bin\openssl.exe" (
        set "PATH=C:\Program Files\Git\usr\bin;%PATH%"
    )
)

set "SECRETS_DIR=%PROJECT_DIR%\secrets"
if not exist "%SECRETS_DIR%" mkdir "%SECRETS_DIR%"
set "ENC_FILE=%SECRETS_DIR%\.env.encrypted"

<nul set /p ="!MASTER_PASS!"| openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 ^
    -in "%ENV_FILE%" ^
    -out "!ENC_FILE!" ^
    -pass stdin 2>nul

if !ERRORLEVEL! neq 0 (
    echo [错误] 加密失败，配置文件仍为明文保存。
    echo        请稍后运行 scripts\encrypt.bat 手动加密。
) else (
    echo [OK] 配置已加密保护！
    echo [信息] 加密备份已保存到 secrets\.env.encrypted
    REM 安全擦除明文.env
    powershell -NoProfile -Command "$f='!ENV_FILE!'; if(Test-Path $f){$s=(Get-Item $f).Length; $r=New-Object byte[] $s; [Security.Cryptography.RandomNumberGenerator]::Fill($r); [IO.File]::WriteAllBytes($f,$r)}" 2>nul
    del /q "!ENV_FILE!" 2>nul
    echo        明文 .env 已安全擦除。
)

echo.
echo ===================================================
echo            全部配置完成！
echo ===================================================
echo.
echo   提示: 除了浏览器 WebChat，你还可以接入
echo   Telegram / Discord / Slack / WhatsApp 等
echo   10 种聊天软件来与 AI 对话！
echo.
echo   配置方法: 运行 scripts\setup-channels.bat
echo.
echo   启动脚本将自动启动 PocketClaw。
echo.

popd
exit /b 0
