# ShellMate V2 史诗级全局重构总纲 (The Grand Refactoring Masterplan)

> **文档综述**: 本文档结合了团队前期产品、技术架构师、资深 UI 设计师以及 QA 负责人的所有会审意见。我们将打破“头痛医头”的零散修补，基于当前的 ShellMate 原生 macOS 代码库，从**需求回溯**、**底层架构**到**前端 UI 像素级重构**，为您呈现一套首尾呼应的最高级别重构蓝图。

---

## 🧭 一、 核心需求重塑与破局点

经过近 4.1 万行原生代码的探索，当前 ShellMate 已具备所有重型终端该有的雏形（TTY、SFTP、本地/远程端隧道、智能 AI 推理）。 
但由于野蛮生长，当前系统在面临专业黑客/运维极客高强度使用时，碰到了以下“天花板”：
1. **渲染瓶颈**：随着终端输出量增加，UI 层极度滥用的 SwiftUI 毛玻璃特效（`ultraThinMaterial`）带来了严重的 GPU 发热与卡顿。
2. **逻辑穿梭**：所有建立 SSH 连接、拉取远端 SFTP 目录的操作，全杂糅在拥有上千行的 View 闭包中。
3. **视觉游离**：设计师提供的 Figma 规范（字号、阴影、间距）在实现时被大量写死了“Magic Number”，导致后续组件根本无法复用。

**重构终极需求**：我们需要用一套极其锋利的架构，把 ShellMate 重制为一款 **零卡顿、极简视觉、完全测试驱动** 的现代 AI-Native 效率终端。

---

## 🏗 二、 技术栈与架构体系升维

在之前的探索中，我们曾思考过是否要迁移到 `Rust + Tauri + React (Web端)`。但在深度摸底了 SwiftUI 原生的 `SwiftTerm` 加上 `LibSSH2` 所带来的极限底层性能后，本报告**强烈建议死守原生 macOS 技术圈（Swift 5.x + SwiftUI + AppKit）**，但需要在架构骨架上实施大换血。

### 1. 拆除“巨石”，设立边界 (Swift Packages)
强制将目前单体堆积在 `ShellMate` 主工程中的 100 多个文件拆分为三大独立 Target (模块化)：
- `ShellMateEngine (C/Swift)`: 纯负责封装 `libssh2`，处理所有的密钥交换、Socks5 通道和 TTY 字节流。这个包里绝对不能包含任何 `import SwiftUI`。
- `ShellMateAI (Swift)`: 处理本地知识库、OpenAI API 协议报文打解包。
- `ShellMateUI (SwiftUI)`: 仅仅是界面的壳子，用依赖注入 (DI) 的方式将外部 Engine 以协议（Protocol）形式挂载。

### 2. 强推 MVVM 与依赖隔离
彻底干掉上千行的 `SFTPPanelView.swift` 和 `TerminalController.swift`！
所有的 View 仅通过观察 `@StateObject var viewModel: Protocol` 拿取转换好的 `String` 和 `[Model]`。所有的核心测试将完全基于 ViewModel 编写（不需要启动 UI），瞬间打通自动化高并发黑盒压测的痛点。

---

## 🎨 三、 重点攻坚：UI 实现重构指导指南 (UI Execution Specs)

UI 的重写是本次翻新的重中之重。抛弃传统的命令式代码，按这套**原子化设计系统 (Atomic SwiftUI)** 来搭建视觉库：

### 1. 锁死 Design Tokens (设计法典)
`Shared/Utilities/DesignTokens.swift` 不能只是个摆设。所有参与重构的研发代码必须满足：
- **空间法则**: 绝对禁止 `.padding(15)`。统一使用 `.padding(DesignTokens.Spacing.md)`（即 6, 12, 16, 24 的增量矩阵）。
- **去线留影**: 大面积废除毫无意义的边框 `.stroke`，统一切换为利用 `DesignTokens.Shadow.medium` 和 `.glassCard()` 带来的物理高度与浮光折射感。

### 2. GPU 算力释放行动 (降级毛玻璃)
对于承载了几十万行字体的 `TerminalView`，把背景的 `.background(.ultraThinMaterial)` 完全删除！
使用绝对纯色的深空色系（`Opaque Background`）。将高斯模糊等极度耗费性能的材质**仅仅限量供应给：全局 Sidebar、Top Toolbar 和 弹出浮窗**。

### 3. 三大核心交互板块重塑
如果在开发中遇到这些模块，直接推倒原 UI 面板：

#### 👉 A. SFTP 管理面板重构
- **废弃**卡片平铺和高光列表。
- **引入** macOS 原生的 `Table` 或者更轻薄的极简分隔线列表。确保列表包含 10,000 个文件目录时，UI 层级足够扁平化，没有额外的高斯涂抹引发发烫。使用单色高对比度的 SF Symbol 代替旧文件夹图标。

#### 👉 B. AIAssistant 智能副驾重构
- **废弃**覆盖在屏幕正中央遮挡代码的阻断式对话框。
- **引入** **侧滑抽屉体验 (Trailing Drawer)**。AI 必须贴在主终端的右侧边缘靠拢，允许工程师一边盯着报错输出，一边在右侧顺畅地向 AI 发起提问。为代码高亮语块施加独立的暗色包裹层，解决对比度混淆。

#### 👉 C. Terminal 顶部 Tab 和 空状态
- **Tab 栏压制**：开启了 15 个会话的工程师很容易迷失。未激活的 Tab 削弱色彩为透明状态并附带 `textTertiary`，当前激活的 Tab 必须在上方使用强烈的 `accentPrimary`（电光蓝）高亮线条突击，形成极致的去噪反差。
- **空窗对齐**：必须严丝合缝地重载之前验收的 Figma 交互稿——全英文 "No Active Sessions" 的干净占位页，且绝不带毫无章法的修饰 icon。

---

## 🗓 四、 全局演进阶段 (Sprint Roadmap)

基于这一系列从底层到皮肤的换血计划，团队节奏建议拆分如下：

- **Sprint 01 [削藩与基建]**: 实施底层代码剥离。抽离 `ShellMateEngine`，强推 `BaseViewModel` 结构，并且强制清除所有脱离 Token 管控的 Magic Number 数值。
- **Sprint 02 [边缘换肤]**: 对相对简单的欢迎引导 (WelcomeScreen)、边栏分组 (Sidebar) 以及工具栏实施原子化组件（按第三章指导）编写，验收新 Button 和 Drawer 框架性能。
- **Sprint 03 [三大巨石绞杀战]**: 全团队专断重写 SFTP、AI、Terminal。实行逻辑 ViewModel 的插接，完成这三个超千行代码怪物的重组瘦身。
- **Sprint 04 [QA黑盒与回归]**: 使用已出具的《端到端黑盒测试方案》，开展断网、高频缩放、1万条日志推送的压力盲测，重点查看活动监视器中 CPU 有没有从原来的峰值稳步下降 30% 以上。

---
> 综上，ShellMate 绝非套了一层皮肤的玩具。通过这套需求回溯与 UI/MVVM 的强腕重构，它完全具备成为对标并超越各种市面成熟 SSH 客户端的核心潜力。
