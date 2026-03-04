# TOOLS.md — PocketClaw 能力与工具文档

> 本文件帮助 AI 了解自己在 PocketClaw 环境中的实际能力边界。

## 内置工具

### 1. 文件操作
- **读取/写入/编辑** workspace/ 目录下的文件
- 支持创建子目录和文件
- 可用于记忆持久化（MEMORY.md、USER.md 等）
- **限制**：仅限 workspace/ 目录，无法访问宿主机文件系统

### 2. 网页浏览（Headless Browser）
- 使用内置 Chromium 无头浏览器
- 可以打开网页、提取文本内容、截图
- 可以填写表单、点击按钮、执行页面交互
- 支持中文网页（已安装 CJK 字体）
- **限制**：无头模式（无 GUI），不支持视频/音频播放

### 3. Web Fetch
- 可以通过 URL 获取网页内容作为纯文本
- 适合快速获取文章、文档、API 响应等
- 比浏览器更轻量，适用于不需要 JavaScript 渲染的页面

### 3.5. 网页搜索（Web Search）
- 通过 DuckDuckGo Lite 或 Google 搜索引擎查找信息
- **方法**: 使用浏览器工具打开 `https://lite.duckduckgo.com/lite/?q=关键词` 获取搜索结果
- **备用**: `https://html.duckduckgo.com/html/?q=关键词`（JS精简版）
- 适用场景: 查找最新资讯、技术文档、天气、汇率等实时信息
- **使用技巧**:
  1. 先用 DuckDuckGo Lite 搜索获取结果链接
  2. 然后用 Web Fetch 或浏览器访问具体页面获取详情
  3. 中文搜索建议同时尝试中英文关键词
- **注意**: 搜索引擎可能有频率限制，避免短时间大量搜索

### 4. 定时任务（Cron）
- 设置定时提醒和周期性任务
- 支持自然语言描述时间（如"每天早上9点"）

### 5. Skills 系统
- 创建可复用的工作流脚本
- Skills 保存在持久化目录中，重启不丢失
- 可以被多次调用和组合

### 6. 频道消息
- 收发 Telegram、Discord、Slack、WhatsApp、Signal 等消息
- 需要用户预先配置对应频道的 Token/凭据
- 支持发送文本、图片等内容

## 环境限制

| 限制项 | 详情 |
|--------|------|
| 内存上限 | 2GB |
| 进程数上限 | 128 |
| 临时目录 | /tmp（100MB，不可执行） |
| 网络 | 可出站（API 调用、网页浏览），入站仅本机 127.0.0.1:18789 |
| 权限 | 非 root 用户，无 sudo，不可安装系统包 |
| 持久化 | workspace/、credentials/、sessions/、logs/、skills/ 为持久卷 |
| 敏感信息 | 不可访问 API Key、密码、.env 等配置文件 |
