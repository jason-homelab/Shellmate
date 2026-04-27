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

### 2.2 技术架构层 (Tech Spec/DB)
* 📄 **[技术方案](./技术方案.md)**（v3.0）- 涵盖 4 层架构图、SSH 连接状态机、AI 服务层、系统性能监控、欢迎引导、脚本自动化、录制回放、日志面板、导入导出等新模块设计，以及 Figma-Spec-v2 UI 令牌系统（§3.16）。
* 📄 **[数据库设计文档](./数据库设计文档.md)** - 详述 10 个 Core Data Entity（基于 SQLite）、枚举对应关系、关联层级以及 Keychain 桥接策略。

### 2.3 进度与管理层
* 📄 **[开发进度](./开发进度.md)** - 17 周项目详细 WBS 与 RACI 矩阵，追踪当前项目进展。

### 2.4 UI 设计规范层（Figma Make 直接实现）

> **⚠️ UI 规范唯一来源：Figma Make 原型 `upl5OBUkpLGnOe1u5aQRZ5`（2026-04-26 起）。**
> 所有 UI 实现必须通过 Figma MCP 读取原型源码（`WelcomeScreen.tsx`、`Sidebar.tsx` 等）1:1 实现，不再维护任何本地 Markdown 规范文档。

**Figma Make 文件访问方式：**
```
fileKey: upl5OBUkpLGnOe1u5aQRZ5
MCP 工具: mcp__figma__get_design_context / ReadMcpResourceTool
组件路径: file://figma/make/source/upl5OBUkpLGnOe1u5aQRZ5/src/app/components/
```

**已完成 1:1 实现的组件（按 Figma 组件文件对应）：**
* ✅ `WelcomeScreen.tsx` → `Features/Welcome/WelcomeScreenView.swift`
* ✅ `Toolbar.tsx` → `App/ContentViewToolbar.swift`
* ✅ `Sidebar.tsx` → `Features/Sidebar/SessionSidebarView.swift` + `SessionRowView.swift` + `GroupHeaderView.swift`
* ✅ `Terminal.tsx` → `Features/Terminal/TerminalView.swift`（SwiftTerm 渲染层无法 1:1 映射，已对齐 ToolbarButton hover/圆角样式）
* ✅ `StatusBar.tsx` → `Features/StatusBar/TerminalStatusBarView.swift`
* ✅ `NewSessionDialog.tsx` → `Features/SessionForm/SessionFormSheet.swift` + `Shared/Components/FormComponents.swift`
* ✅ `SettingsDialog.tsx` → `Features/Settings/SettingsView.swift`（Tab bar bg-black/5、active tab bg-white、容器 white/95 backdrop-blur）
* ✅ `AIAssistantPanel.tsx` → `Features/AI/AIAssistantPanelView.swift` + `AICodeBlockView.swift`
* ✅ `FileTransferPanel.tsx` → `Features/SFTP/SFTPPanelView.swift` + `SFTPFileRowViews.swift`

**待实现组件（优先级顺序）：**
* `TmuxManager.tsx` → `Features/Tmux/TmuxManagerView.swift`
* `TunnelManager.tsx` → `Features/Tunnel/TunnelManagerView.swift`
* `QuickCommandManager.tsx` → `Features/QuickCommand/QuickCommandManagerView.swift`
* `ScriptAutomationPanel.tsx` → `Features/Scripts/ScriptLibraryView.swift`
* `RecordingDialog.tsx` → `Features/Recording/RecordingDialogView.swift`
* `LogViewerDialog.tsx` → `Features/Logs/LogPanelView.swift`
* `GroupManagementDialog.tsx` → `Features/Sidebar/GroupManagerView.swift`
* `PasswordManagerDialog.tsx` → `Features/Settings/PasswordManagerView.swift`
* `SessionImportExportDialog.tsx` → `Features/SessionForm/SessionImportExportView.swift`

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
