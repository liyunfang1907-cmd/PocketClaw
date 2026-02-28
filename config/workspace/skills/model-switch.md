# Skill: 模型切换

## 描述
帮助用户切换 AI 模型提供商。用户可以直接告诉你新的 API Key 和提供商名称，你会保存配置并指导用户重启。

## 支持的提供商

| 提供商 | PROVIDER_NAME | 默认模型 | 获取 API Key |
|--------|---------------|----------|-------------|
| 智谱 AI | zhipu | glm-4.7-flash | https://open.bigmodel.cn |
| DeepSeek | deepseek | deepseek-chat | https://platform.deepseek.com |
| Moonshot/Kimi | moonshot | moonshot-v1-auto | https://platform.moonshot.cn |
| 通义千问 | qwen | qwen-turbo-latest | https://dashscope.console.aliyun.com |
| 零一万物 | yi | yi-lightning | https://platform.lingyiwanwu.com |
| 硅基流动 | siliconflow | deepseek-ai/DeepSeek-V3 | https://cloud.siliconflow.cn |

## 操作流程

### 当用户提供 API Key 并指定提供商时
例如用户说："我的 DeepSeek API Key 是 sk-xxx" 或 "帮我切换到智谱，key是xxx"

1. 识别提供商名称（映射到上表的 PROVIDER_NAME）
2. 提取 API Key
3. 写入文件 `workspace/.provider`，格式如下：
```
# PocketClaw Provider Config
PROVIDER_NAME=<provider>
API_KEY=<key>
MODEL_ID=<default_model>
```
4. 回复用户：
   - 告知已保存配置
   - 告知需要重启才能生效
   - 提供重启方法：运行 `scripts/stop.bat` 然后 `scripts/start.bat`，或双击 `PocketClaw.bat` 选择启动

### 当用户只提供 API Key（没说是哪家的）
1. 根据 Key 的格式推测提供商：
   - 以数字开头且包含 `.` 的长字符串 → 智谱
   - 以 `sk-` 开头 → 可能是 DeepSeek/Moonshot/Yi/硅基流动，需要询问
2. 如果无法确定，询问用户是哪家的

### 当用户问如何切换模型
1. 告知两种方式：
   - **方式一（推荐）**：直接把 API Key 发给我，告诉我是哪家的，我帮你配置
   - **方式二**：运行 `scripts/change-api.bat`（PocketClaw.bat 菜单第4项），按菜单操作

### 当用户问支持哪些模型
列出上表中所有支持的提供商和模型

## 安全提醒
- API Key 保存在 workspace/.provider 文件中
- 不要在对话中重复或显示完整的 API Key
- 保存后只显示前8位 + ****
