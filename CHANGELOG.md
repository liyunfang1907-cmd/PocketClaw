# Changelog

All notable changes to PocketClaw will be documented in this file.

## [1.3.1] - 2026-03-06

### Fixed
- 修复手机扫码页面 Internal Server Error（Dockerfile 中 mobile.html 复制后未 chown 给 node 用户）
- macOS 控制面板状态显示优化：地址始终带 Token、新增手机访问地址和模型健康状态
- Docker 幽影容器防护：docker run 失败时自动用备用容器名重试

## [1.2.4] - 2026-03-04

### Security
- Gateway: 移除 allowedOrigins 中的 `"null"` 项，添加安全配置说明注释
- 修复 mobile.html Markdown 渲染器 XSS 漏洞（过滤 javascript: 等危险协议）
- 限制调试用全局变量仅在开发模式下暴露

### Improved
- 增强 Markdown 渲染：新增标题(h1-h4)、表格、删除线、水平线、代码块保护
- 聊天记录改用 JSON 结构化存储（替代 raw innerHTML，上限 200 条）
- TTS 文本截断阈值提取为可配置常量
- 新增 .editorconfig 统一编辑器行为
- 新增 CHANGELOG.md 版本变更记录

### Fixed
- 修复 landing page 下载追踪代码中版本号不一致的问题

## [1.2.3] - 2026-03-03

### Fixed
- 手机页面完整修复：AI 回复显示、聊天记录持久化、页面切换自动重连
- 修复 `catch {}` ES2019 语法兼容性问题（改为 `catch(e) {}`）
- 修复 sessionKey 匹配逻辑（改用 indexOf 包含匹配）
- 修复 scopes 配置（`[]` → `['operator.admin']`）
- 修复 CSP 阻止 mobile.html 加载的问题
- 修复 Windows 版本检查 TLS 问题

## [1.2.2] - 2026-03-03

### Fixed
- Windows 版本检查 TLS 修复
- Docker 等待计时器修复
- 移除桌面语音按钮
- 手机页面 WebSocket 连接修复

## [1.2.0] - 2026-03-03

### Added
- Docker 智能构建跳过（文件指纹比对，秒级二次启动）
- 手机专属界面 + QR 码扫码访问
- Colima 兼容支持

### Fixed
- CSP 安全头修复
- 启动脚本稳定性增强
- 移除浏览器自动弹出

## [1.1.2] - 2026-03-02

### Added
- 手机主屏幕 PWA 支持
- Windows 防火墙自动配置

### Fixed
- 浏览器配置修复
- URL 路径修正
- 弃用 API 替换

## [1.1.1] - 2026-03-02

### Added
- OpenClaw 升级至 2026.3.1
- Chromium 无头浏览器集成
- Docker 健康检查
- Skills 持久化存储
- 局域网访问支持

### Improved
- Windows 启动优化

## [1.1.0] - 2026-03-01

### Added
- 10 种聊天频道支持 (Telegram/Discord/Slack/WhatsApp/Signal 等)
- 长期记忆系统
- AI 身份持久化

### Improved
- macOS/Windows 双系统完美适配

## [1.0.3] - 2026-02-27

### Added
- 首个公开版本
- GLM-4.7-Flash 免费模型默认集成
- AES-256-CBC 加密存储
- 全自动环境安装 (Docker/WSL2/镜像加速)
- 中文交互界面
