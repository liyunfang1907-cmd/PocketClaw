# TOOLS.md — PocketClaw 能力与工具文档

> 本文件帮助 AI 了解自己在 PocketClaw 环境中的实际能力边界。

## 内置工具

### 1. 文件操作
- **读取/写入/编辑** workspace/ 目录下的文件
- 支持创建子目录和文件
- 可用于记忆持久化（MEMORY.md、USER.md 等）
- **用户文件请保存到 `../工作区/`**（对应 U 盘 `PocketClaw/工作区/` 文件夹，与 workspace 完全隔离）
- workspace/ 目录存放系统配置文件（AGENTS.md、SOUL.md 等），不要在这里创建用户文件
- **限制**：仅限 workspace/ 及同级目录，无法访问宿主机文件系统

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
- 已内置多种技能（文件处理、笔记、待办、定时提醒、文本工具）
- 可通过 `clawhub` CLI 搜索和安装更多社区技能
- 安装新技能：提示用户在控制面板的 Skills 页面操作，或使用 `clawhub search <关键词>` / `clawhub install <技能名>`
- Skills 保存在持久化目录中，重启不丢失
- 可以被多次调用和组合

### 6. 频道消息
- 收发 Telegram、Discord、Slack、WhatsApp、Signal 等消息
- 需要用户预先配置对应频道的 Token/凭据
- 支持发送文本、图片等内容

### 7. 自诊断修复（Doctor）
- PocketClaw 内置了自诊断修复工具，用户可通过控制面板菜单 **[6] 自诊断修复** 运行
- 检查 10 个诊断项：Docker 安装、引擎运行、镜像、容器状态、端口、配置文件、API Key、加密状态、磁盘空间、容器日志
- 发现问题时会自动尝试修复（重启容器、清理磁盘等），并调用 AI 分析原因
- 诊断报告保存到 `data/logs/doctor-*.txt`
- **你可以在容器内读取最近的诊断报告**：检查 `../logs/` 目录下的 `doctor-*.txt` 文件
- **当用户遇到以下问题时，建议用户运行自诊断修复：**
  - 页面无法访问 / 连接失败
  - 回复异常（不说话、报错）
  - 容器状态异常
  - API Key 失效
  - 磁盘空间不足

### 8. 图片处理
- 使用 Pillow 库处理图片：调整尺寸、格式转换、裁剪、拼图、添加水印
- 支持 PNG/JPEG/GIF/WEBP/BMP/TIFF
- 详见 `workspace/skills/image-tools.md`

### 9. PPT 生成
- 使用 python-pptx 生成 PowerPoint 演示文稿
- 支持标题页、内容页、插入图片、自定义字体
- 详见 `workspace/skills/ppt-generator.md`

### 10. 数据分析与图表
- 使用 pandas 分析 CSV/Excel 数据：筛选、分组统计、透视表、排序
- 使用 matplotlib 生成图表：柱状图、折线图、饼图、散点图
- 支持中文显示（已安装 CJK 字体）
- 详见 `workspace/skills/data-analysis.md`

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
