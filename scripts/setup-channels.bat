@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM setup-channels.bat  —— 聊天频道配置向导 [Windows]
REM 用法: scripts\setup-channels.bat
REM ============================================================

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_DIR=%CD%"
set "ENV_FILE=%PROJECT_DIR%\.env"
set "CONFIGURED=0"

REM --------------- 检查 .env ---------------
if not exist "%ENV_FILE%" (
    if exist "%PROJECT_DIR%\secrets\.env.encrypted" (
        echo [提示] 需要先解密 .env 文件
        if exist "%SCRIPT_DIR%decrypt.bat" (
            call "%SCRIPT_DIR%decrypt.bat"
            if not exist "%ENV_FILE%" (
                echo [错误] 解密失败，请先运行 setup-env.bat 完成基础配置
                goto :done
            )
        ) else (
            echo [错误] 未找到解密脚本，请先运行 setup-env.bat 完成基础配置
            goto :done
        )
    ) else (
        echo [错误] 未找到 .env 文件，请先运行 setup-env.bat 完成基础配置
        goto :done
    )
)

REM === 菜单显示 ===
echo.
echo ====================================================
echo        PocketClaw 聊天频道配置向导
echo    除了默认的 WebChat，你还可以接入更多聊天软件
echo ====================================================
echo.
echo   PocketClaw 默认已启用 WebChat（浏览器聊天界面）。
echo   以下频道均为可选配置，按需启用即可。
echo.
echo   +--------------------------------------------+
echo   ^|  可选频道:                                 ^|
echo   ^|                                            ^|
echo   ^|  1. Telegram    - 最简单，推荐首选         ^|
echo   ^|  2. Discord     - 游戏/社区用户推荐        ^|
echo   ^|  3. Slack       - 办公场景推荐             ^|
echo   ^|  4. WhatsApp    - 海外用户推荐             ^|
echo   ^|  5. Signal      - 隐私优先推荐             ^|
echo   ^|  6. Google Chat - Google 生态用户          ^|
echo   ^|  7. MS Teams    - 企业办公推荐             ^|
echo   ^|  8. Matrix      - 开源去中心化聊天         ^|
echo   ^|  9. BlueBubbles - iMessage (需 macOS^)     ^|
echo   ^| 10. Zalo        - 越南市场                 ^|
echo   ^|                                            ^|
echo   ^|  0. 跳过，不配置额外频道                   ^|
echo   +--------------------------------------------+
echo.

set "CHANNEL_INPUT="
set /p "CHANNEL_INPUT=  请输入要配置的频道编号（多个用逗号分隔，如 1,2）: "

if "!CHANNEL_INPUT!"=="" goto :skip_channels
if "!CHANNEL_INPUT!"=="0" goto :skip_channels

REM === 解析输入，设置标志位 ===
set "DO_1=" & set "DO_2=" & set "DO_3=" & set "DO_4=" & set "DO_5="
set "DO_6=" & set "DO_7=" & set "DO_8=" & set "DO_9=" & set "DO_10="
for %%c in (!CHANNEL_INPUT!) do (
    set "TC=%%c"
    set "TC=!TC: =!"
    if "!TC!"=="1" set "DO_1=1"
    if "!TC!"=="2" set "DO_2=1"
    if "!TC!"=="3" set "DO_3=1"
    if "!TC!"=="4" set "DO_4=1"
    if "!TC!"=="5" set "DO_5=1"
    if "!TC!"=="6" set "DO_6=1"
    if "!TC!"=="7" set "DO_7=1"
    if "!TC!"=="8" set "DO_8=1"
    if "!TC!"=="9" set "DO_9=1"
    if "!TC!"=="10" set "DO_10=1"
)

if defined DO_1 call :cfg_telegram
if defined DO_2 call :cfg_discord
if defined DO_3 call :cfg_slack
if defined DO_4 call :cfg_whatsapp
if defined DO_5 call :cfg_signal
if defined DO_6 call :cfg_gchat
if defined DO_7 call :cfg_teams
if defined DO_8 call :cfg_matrix
if defined DO_9 call :cfg_bluebubbles
if defined DO_10 call :cfg_zalo
goto :finish_channels

REM === 各频道配置段 ===

:cfg_telegram
echo.
echo -- 配置 Telegram --
echo   你需要一个 Telegram Bot Token。
echo   获取方法: 在 Telegram 中搜索 @BotFather → /newbot → 按提示创建
echo.
set "TG_TOKEN="
set /p "TG_TOKEN=  请粘贴你的 Bot Token: "
if "!TG_TOKEN!"=="" (
    echo   已跳过 Telegram
) else (
    echo TELEGRAM_BOT_TOKEN=!TG_TOKEN!>> "%ENV_FILE%"
    echo   [OK] Telegram 已配置
    set /a CONFIGURED+=1
)
goto :eof

REM === Discord 配置段 ===

:cfg_discord
echo.
echo -- 配置 Discord --
echo   你需要一个 Discord Bot Token。
echo   获取方法: https://discord.com/developers/applications
echo   创建应用 → Bot → Reset Token → 复制
echo.
set "DC_TOKEN="
set /p "DC_TOKEN=  请粘贴你的 Bot Token: "
if "!DC_TOKEN!"=="" (
    echo   已跳过 Discord
) else (
    echo DISCORD_BOT_TOKEN=!DC_TOKEN!>> "%ENV_FILE%"
    echo   [OK] Discord 已配置
    set /a CONFIGURED+=1
)
goto :eof

REM === Slack 配置段 ===

:cfg_slack
echo.
echo -- 配置 Slack --
echo   你需要 Slack Bot Token 和 App Token。
echo   获取方法: https://api.slack.com/apps → 创建应用
echo   Bot Token (xoxb-...^) 在 OAuth ^& Permissions 页面
echo   App Token (xapp-...^) 在 Basic Information → App-Level Tokens
echo.
set "SLACK_BOT="
set /p "SLACK_BOT=  请粘贴 Bot Token (xoxb-...): "
set "SLACK_APP="
set /p "SLACK_APP=  请粘贴 App Token (xapp-...): "
if "!SLACK_BOT!"=="" (
    echo   已跳过 Slack
) else if "!SLACK_APP!"=="" (
    echo   已跳过 Slack（需要同时填写两个 Token）
) else (
    echo SLACK_BOT_TOKEN=!SLACK_BOT!>> "%ENV_FILE%"
    echo SLACK_APP_TOKEN=!SLACK_APP!>> "%ENV_FILE%"
    echo   [OK] Slack 已配置
    set /a CONFIGURED+=1
)
goto :eof

REM === WhatsApp+Signal 配置段 ===

:cfg_whatsapp
echo.
echo -- 配置 WhatsApp --
echo   WhatsApp 使用 Baileys 协议，需要扫码链接设备。
echo   首次启动后在容器日志中会显示二维码，用 WhatsApp 扫描即可。
echo   这里只需填写允许与 AI 对话的手机号码。
echo.
set "WA_NUMS="
set /p "WA_NUMS=  请输入允许的手机号（含国际区号，多个用逗号分隔）: "
if "!WA_NUMS!"=="" (
    echo   已跳过 WhatsApp
) else (
    echo WHATSAPP_ALLOW_FROM=!WA_NUMS!>> "%ENV_FILE%"
    echo   [OK] WhatsApp 已配置
    echo   [注意] 首次启动时请查看日志扫码: docker compose logs -f pocketclaw
    set /a CONFIGURED+=1
)
goto :eof

:cfg_signal
echo.
echo -- 配置 Signal --
echo   Signal 需要安装 signal-cli 并注册号码。
echo   详见: https://docs.openclaw.ai/channels/signal
echo.
set "SIG_NUM="
set /p "SIG_NUM=  请输入 Signal 注册手机号（如 +8613800138000）: "
if "!SIG_NUM!"=="" (
    echo   已跳过 Signal
) else (
    echo SIGNAL_PHONE_NUMBER=!SIG_NUM!>> "%ENV_FILE%"
    echo   [OK] Signal 已配置
    echo   [注意] 还需要在容器内配置 signal-cli，详见文档
    set /a CONFIGURED+=1
)
goto :eof

REM === GChat+Teams 配置段 ===

:cfg_gchat
echo.
echo -- 配置 Google Chat --
echo   需要 Google Cloud 项目的服务账号密钥文件。
echo   详见: https://docs.openclaw.ai/channels/googlechat
echo.
set "GC_CRED="
set /p "GC_CRED=  服务账号 JSON 密钥文件路径: "
if "!GC_CRED!"=="" (
    echo   已跳过 Google Chat
) else (
    echo GOOGLE_CHAT_CREDENTIALS=!GC_CRED!>> "%ENV_FILE%"
    set "GC_SPACE="
    set /p "GC_SPACE=  Chat Space ID（可选，回车跳过）: "
    if not "!GC_SPACE!"=="" (
        echo GOOGLE_CHAT_SPACES=!GC_SPACE!>> "%ENV_FILE%"
    )
    echo   [OK] Google Chat 已配置
    set /a CONFIGURED+=1
)
goto :eof

:cfg_teams
echo.
echo -- 配置 Microsoft Teams --
echo   需要 Azure Bot Framework 的 App ID 和 App Password。
echo   详见: https://docs.openclaw.ai/channels/msteams
echo.
set "MS_ID="
set /p "MS_ID=  App ID: "
set "MS_PASS="
set /p "MS_PASS=  App Password: "
if "!MS_ID!"=="" (
    echo   已跳过 Microsoft Teams
) else if "!MS_PASS!"=="" (
    echo   已跳过 Microsoft Teams（需要同时填写 ID 和 Password）
) else (
    echo MSTEAMS_APP_ID=!MS_ID!>> "%ENV_FILE%"
    echo MSTEAMS_APP_PASSWORD=!MS_PASS!>> "%ENV_FILE%"
    echo   [OK] Microsoft Teams 已配置
    set /a CONFIGURED+=1
)
goto :eof

REM === Matrix+BB+Zalo 配置段 ===

:cfg_matrix
echo.
echo -- 配置 Matrix --
echo   你需要 Matrix Homeserver URL、User ID 和 Access Token。
echo   可以使用 matrix.org 或自建服务器。
echo.
set "MX_HOME="
set /p "MX_HOME=  Homeserver URL (如 https://matrix.org): "
set "MX_USER="
set /p "MX_USER=  User ID (如 @mybot:matrix.org): "
set "MX_TOKEN="
set /p "MX_TOKEN=  Access Token: "
if "!MX_HOME!"=="" (
    echo   已跳过 Matrix
) else if "!MX_USER!"=="" (
    echo   已跳过 Matrix（需要填写全部三项）
) else if "!MX_TOKEN!"=="" (
    echo   已跳过 Matrix（需要填写全部三项）
) else (
    echo MATRIX_HOMESERVER=!MX_HOME!>> "%ENV_FILE%"
    echo MATRIX_USER_ID=!MX_USER!>> "%ENV_FILE%"
    echo MATRIX_ACCESS_TOKEN=!MX_TOKEN!>> "%ENV_FILE%"
    echo   [OK] Matrix 已配置
    set /a CONFIGURED+=1
)
goto :eof

:cfg_bluebubbles
echo.
echo -- 配置 BlueBubbles (iMessage^) --
echo   需要在 macOS 上运行 BlueBubbles Server。
echo   详见: https://docs.openclaw.ai/channels/bluebubbles
echo.
set "BB_URL="
set /p "BB_URL=  BlueBubbles Server URL (如 http://192.168.1.100:1234): "
set "BB_PASS="
set /p "BB_PASS=  Server Password: "
if "!BB_URL!"=="" (
    echo   已跳过 BlueBubbles
) else if "!BB_PASS!"=="" (
    echo   已跳过 BlueBubbles（需要同时填写 URL 和 Password）
) else (
    echo BLUEBUBBLES_SERVER_URL=!BB_URL!>> "%ENV_FILE%"
    echo BLUEBUBBLES_PASSWORD=!BB_PASS!>> "%ENV_FILE%"
    echo   [OK] BlueBubbles 已配置
    set /a CONFIGURED+=1
)
goto :eof

:cfg_zalo
echo.
echo -- 配置 Zalo --
echo   需要 Zalo Official Account 的 Access Token。
echo   详见: https://developers.zalo.me/
echo.
set "ZA_TOKEN="
set /p "ZA_TOKEN=  OA Access Token: "
if "!ZA_TOKEN!"=="" (
    echo   已跳过 Zalo
) else (
    echo ZALO_OA_ACCESS_TOKEN=!ZA_TOKEN!>> "%ENV_FILE%"
    echo   [OK] Zalo 已配置
    set /a CONFIGURED+=1
)
goto :eof

REM === 完成逻辑 ===

:finish_channels
echo.
if !CONFIGURED! GTR 0 (
    echo ====================================================
    echo    [OK] 已配置 !CONFIGURED! 个额外频道
    echo ====================================================
    echo.
    echo   频道配置已写入 .env 文件。
    echo   正在重新加密 .env 以保护敏感信息...
    echo.

    REM 重新加密
    if exist "%SCRIPT_DIR%encrypt.bat" (
        call "%SCRIPT_DIR%encrypt.bat"
    ) else (
        echo   [警告] 未找到加密脚本，.env 将以明文保存
    )

    echo.
    echo   [注意] 需要重启 PocketClaw 才能生效:
    echo          scripts\stop.bat
    echo          scripts\start.bat
) else (
    echo   未配置任何频道，保持当前设置不变。
)
goto :done

:skip_channels
echo.
echo   已跳过频道配置，仅使用 WebChat。
goto :done

:done
popd
exit /b 0
