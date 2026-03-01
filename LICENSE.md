# PocketClaw 许可协议与免责声明

## 一、版权声明

Copyright (c) 2026 PocketClaw 项目作者

本项目中的部署脚本（scripts/ 目录下所有文件）、配置方案（docker-compose.yml、
Dockerfile.custom）、文档（README.md、注意事项.md、使用指南.txt）
均为项目作者原创作品，受著作权法保护。

## 二、OpenClaw 上游许可

本项目使用的 OpenClaw 核心软件采用 MIT 许可证发布，原始许可证如下：

> MIT License
>
> Copyright (c) OpenClaw Contributors
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## 三、使用许可

### 允许的行为

- ✅ 个人学习和使用
- ✅ 复制到自己的 U 盘/设备上供个人使用
- ✅ 在保留本许可文件的前提下，分享给朋友供个人使用

### 禁止的行为

- ❌ 修改后以原作者名义再分发
- ❌ 将本项目用于商业销售或盈利
- ❌ 移除或修改本许可文件和免责声明
- ❌ 共享他人的 API Key 或加密凭证

## 四、免责声明

**本项目按"原样"提供，不附带任何形式的明示或暗示担保。**

### 4.1 使用风险

使用者确认并同意：

1. **自担风险**：使用本项目所产生的一切后果由使用者自行承担
2. **无安全保证**：虽然本项目已实施多项安全措施（AES-256 加密、容器隔离、
   安全擦除等），但作者不保证这些措施在所有环境下均绝对有效
3. **无可用性保证**：作者不保证本项目在所有硬件、操作系统、Docker 版本上
   均能正常运行
4. **API 费用**：使用者应使用自己的 API Key，因使用本项目产生的 API 调用
   费用由使用者自行承担

### 4.2 免责范围

在法律允许的最大范围内，项目作者不对以下情况承担任何责任：

- 因软件缺陷（bug）导致的数据丢失、泄露或损坏
- 因密码遗忘导致的加密数据无法恢复
- 因 API Key 泄露导致的经济损失
- 因 U 盘丢失、损坏导致的任何后果
- 因使用者自行修改代码导致的任何问题
- 因第三方服务（Docker、智谱、Telegram 等）变更导致的功能异常
- 任何直接的、间接的、附带的、特殊的或惩罚性的损害赔偿

### 4.3 修改代码的后果

如使用者自行修改了本项目中的任何文件：

1. 作者不再对修改后的版本提供技术支持
2. 修改可能导致安全防护失效，由此产生的风险由修改者自行承担
3. 修改后的版本不得以原作者名义进行分发

## 五、完整性校验

本项目包含文件完整性校验功能（scripts/verify-integrity.sh）。
启动时会自动检测关键文件是否被篡改：

- 若检测到文件被修改，将显示警告信息
- 校验失败不会阻止启动，但使用者应知悉风险
- 可运行 `bash scripts/verify-integrity.sh` 手动检查

## 六、联系方式

如有问题或发现安全漏洞，请联系项目作者。

---

*最后更新: 2026-02-26*
