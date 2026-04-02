# ShellMate 项目基础配置文档 (CLAUDE.md)

> **⚠️ AI 助手核心强制规则（Primary Directives）**
> 1. **全中文交流**：所有的对答、文档编写、代码注释、Commit Message **必须**使用中文。
> 2. **执行后自检**：每次完成一个功能或修改后，**必须**主动自检一遍是否真正满足了需求，是否存在遗漏或边缘情景。不要等我指出问题才去修补。
> 3. **默认上下文**：每次会话请隐式加载本文件的规范和下方列出的核心设计文档。

---

## 1. 项目概览

ShellMate 是一款面向专业开发者/运维工程师的 macOS 原生 SSH 会话管理工具。主要通过 SwiftUI + AppKit 组合实现系统级原生体验，底层集成 `libssh2` 与 `SwiftTerm`，采用 Core Data + CloudKit 进行数据同步，使用系统 Keychain 进行凭证保护。

---

## 2. 核心设计文档索引

在进行需求开发、架构设计或代码变动前，请优先参考以下基础文档（严格遵循文档中的定义，不要自行发明不一致的数据结构或设计）：

### 2.1 需求与定义层 (MRD/PRD)
* 📄 **[ShellMate MRD](./ShellMate_MRD.md)** - 明确产品定位、目标用户群和各阶段里程碑目标。
* 📄 **[ShellMate PRD](./ShellMate_PRD.md)** - 详细的功能模块定义、数据模型（10章）、错误处理规范和 10 个 P0 级验收用例。
* 📄 **[原型设计规范](./原型.md)** - 线框图与组件布局定义（ASCII 格式），涵盖完整的弹窗、覆层及错误弹窗细节。

### 2.2 技术架构层 (Tech Spec/DB)
* 📄 **[技术方案](./技术方案.md)**（v3.0）- 涵盖 4 层架构图、SSH 连接状态机、AI 服务层、系统性能监控、欢迎引导、脚本自动化、录制回放、日志面板、导入导出等新模块设计，以及 Figma-Spec-v2 UI 令牌系统（§3.16）。
* 📄 **[数据库设计文档](./数据库设计文档.md)** - 详述 10 个 Core Data Entity（基于 SQLite）、枚举对应关系、关联层级以及 Keychain 桥接策略。

### 2.3 进度与管理层
* 📄 **[开发进度](./开发进度.md)** - 17 周项目详细 WBS 与 RACI 矩阵，追踪当前项目进展。

### 2.4 UI 设计规范层 (Figma Specs)

> **⚠️ 规范权威性声明：`Figma-Spec-v2/` 为当前唯一权威 UI 设计规范（2026-04-02 起）。**
> 所有新功能开发、UI 改动必须以 v2 为准。旧版 `shellmate-figma-spec/` 仅供历史参考，存在冲突时 **v2 优先**。

#### ✅ 当前权威规范：`./Figma-Spec-v2/`（基于 Figma Make 原型 `upl5OBUkpLGnOe1u5aQRZ5`，2026-04-02）

* **[`00-总纲与设计令牌.md`](./Figma-Spec-v2/00-总纲与设计令牌.md)** - 颜色令牌（Apple Blue `#007aff` / 语义色）、排版令牌（8级）、间距/圆角/阴影/动效令牌、图标规范（SF Symbols 映射）、Z轴层次。
* **[`01-整体布局规范.md`](./Figma-Spec-v2/01-整体布局规范.md)** - 主界面层次（标题栏40/工具栏48/侧边栏256/终端flex/状态栏32）、四种分屏模式（单/水平/垂直/四格）、脚本自动化覆层。
* **[`02-侧边栏规范.md`](./Figma-Spec-v2/02-侧边栏规范.md)** - 容器、顶部工具行（新建/分组管理/密码管理/设置）、会话行（选中/未选中）、文件夹行、ScrollArea。
* **[`03-工具栏规范.md`](./Figma-Spec-v2/03-工具栏规范.md)** - 三区段布局（左侧10个操作按钮/中间会话名/右侧4个全局按钮）、分屏下拉菜单、按钮通用样式。
* **[`04-终端区域规范.md`](./Figma-Spec-v2/04-终端区域规范.md)** - 标签栏、终端视图、AI 命令说明 Tooltip、AI 错误建议条（内联）、终端主题切换。
* **[`05-状态栏规范.md`](./Figma-Spec-v2/05-状态栏规范.md)** - 连接状态指示、CPU/内存/磁盘/网络实时指标（颜色阈值/迷你图/进度条）、2s 刷新频率。
* **[`06-新建会话弹窗规范.md`](./Figma-Spec-v2/06-新建会话弹窗规范.md)** - 单页表单（名称/协议/主机/端口/用户名/密码/分组），`max-w-[500px]`，字段验证规则。
* **[`07-设置面板规范.md`](./Figma-Spec-v2/07-设置面板规范.md)** - **3 Tab 结构**（通用/外观/终端），`max-w-[600px]`，Switch 组件规范。
* **[`08-文件传输面板规范.md`](./Figma-Spec-v2/08-文件传输面板规范.md)** - 双面板布局（本地/远程）、文件列表项、传输进度条、底部状态栏，`W: 500px`。
* **[`09-AI助手面板规范.md`](./Figma-Spec-v2/09-AI助手面板规范.md)** - 消息气泡（AI左/用户右）、命令块（含复制/执行）、Typing 指示器、快速提示、输入区，`W: 400px`。
* **[`10-tmux管理器规范.md`](./Figma-Spec-v2/10-tmux管理器规范.md)** - 三 Tab（Sessions/Windows/Quick Actions）、会话卡片（附加态渐变）、窗口卡片、快捷操作 2×2 Grid，`max-w-[900px]`。
* **[`11-隧道管理器规范.md`](./Figma-Spec-v2/11-隧道管理器规范.md)** - 隧道列表/新建表单、三种类型（本地/远程/SOCKS5）、状态切换按钮，`max-w-[700px]`。
* **[`12-快捷命令管理器规范.md`](./Figma-Spec-v2/12-快捷命令管理器规范.md)** - 分类标题、命令卡片（执行/编辑/删除）、新建表单，`max-w-[700px]`。
* **[`13-欢迎界面规范.md`](./Figma-Spec-v2/13-欢迎界面规范.md)** - 三步骤 Onboarding（欢迎/特性/开始），英雄图标、步骤指示器（当前步蓝色宽条）、操作卡片 3 列，z-50 全屏。
* **[`14-其他弹窗规范.md`](./Figma-Spec-v2/14-其他弹窗规范.md)** - 分组管理、密码管理、导入/导出（JSON/CSV）、日志面板（过滤/搜索/导出）、脚本自动化面板（全屏双栏）、录制对话框、弹窗统一规范汇总。

#### 📦 历史参考（仅供查阅，不作为实现依据）：`./shellmate-figma-spec/`

旧版规范中 `shellmate-figma-spec/03-动效与交互规范.md`、`04-可访问性与Handoff检查清单.md` 中的 VoiceOver / 动效弹性曲线部分仍有参考价值，v2 未覆盖时可查阅。其余文件已被 v2 完全替代。

---

## 3. 项目开发规范

### 3.1 技术选型与工具链
* **开发语言**: Swift 5.9+
* **最低部署目标**: macOS 13.0 (Ventura)
* **响应式 UI**: SwiftUI (主框架) + AppKit (NSViewRepresentable 用于终端等高复杂度视图)
* **数据持久化**: Core Data搭配 `NSPersistentCloudKitContainer` (启用 `@Model` 前留意 macOS 14 兼容性，本项目目前仍建议传统 Core Data 方式)
* **凭据保护**: macOS Keychain Services
* **SSH引擎**: libssh2 (通过 XCFramework 静态包裹，隔离 Homebrew 依赖)
* **终端渲染**: SwiftTerm

### 3.2 代码与架构规范
1. **单向数据流与状态管理**
   * UI 不要直接产生副作用，必须交由 `@MainActor` 标记的 ViewModels / Store (`ObservableObject`)。
   * Store 的 State 数据对外暴露 `@Published` (只读倾向)。
2. **Swift Concurrency 优先**
   * 全面弃用 GCD（回调 / closure），采用 `async / await`。
   * 将高消耗后台任务（如 SSH IO 读取）放入单独的 `actor`，避免阻塞主线程。
3. **安全第一的原则**
   * 任何密码（SSH 密码、Passphrase、主密码 Hash）**严禁**落入 Core Data、日志、控制台。
   * 私钥原文和密码只存在于本设备 Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)。

### 3.3 测试规范
* **结构化测试**: 划分 `UnitTests`（业务逻辑、Store 状态流转）与 `IntegrationTests`（实际网络 IO、DB 操作）。
* **UI无关测试**: 所有的格式校验、URL 拼接、SSH Handshake 状态机均应当具备完善的 XCTest。
* **Mock 注入**: 面向 Protocol 编程（如 `SSHConnectionServiceProtocol`），在单元测试中使用 Mock 对象隔离物理依赖环境。

### 3.4 Git 工作流与提交规范
* **分支策略**: 采用 Feature Branch 工作流（`main` 为主分支，所有开发在 `feature/` 或 `bugfix/` 分支进行）。
* **Commit 规范**: 统一采用 Angular 风格（使用中文撰写提交说明）。
  * 格式：`<type>(<scope>): <subject>`
  * 范例：`feat(ssh): 添加 ed25519 密钥认证支持`
  * 常见 type：`feat` (新功能), `fix` (修复 bug), `docs` (文档更新), `style` (代码格式变动), `refactor` (重构), `test` (增加测试), `chore` (构建过程或辅助工具变动)。

### 3.5 部署与分发规范
本应用存在两个相互独立的分发目标，在 Xcode 需要设置双 Target 或依靠宏来隔离功能：
1. **App Store 版**: 限制更严，启用完整的 `App Sandbox` Entitlements。禁止/屏蔽直接访问 `SSH_AUTH_SOCK` (SSH Agent)。
2. **官网 Direct 版**: 不启用 Sandbox 或按需配置。拥有完整能力（包含访问本地 SSH 代理套接字）。必须包含完整的 `notarytool` 签名认证流以通过 macOS Gatekeeper。

---

*(最后重申：作为本项目的 AI 协作者，你在产出代码或回答前，必须应用上述所有强制规则与技术规范，并在完成步骤时进行反思式自检。)*

---

## 4. 测试环境

### 4.1 真机测试服务器
| 字段 | 值 |
|------|-----|
| IP 地址 | 192.168.100.167 |
| 用户名 | ubuntu |
| 密码 | Int3l@123 |
| IP 地址 | 192.168.100.120|
| 用户名 | ubuntu |
| 密码 | Int3l@123 |
