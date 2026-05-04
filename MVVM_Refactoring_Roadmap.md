# ShellMate 史诗级全局重构推进白皮书 (MVVM Grand Refactoring Roadmap)

> **文档版本：** v2.0
> **最后更新：** 2026-04-15
> **制定者：** AI 架构师 + 资深 UI/UX 设计师（联合输出）
> **上级文档：** [ShellMate_Grand_Refactoring_Masterplan.md](./ShellMate_Grand_Refactoring_Masterplan.md) · [UI_Design_Review.md](./UI_Design_Review.md)
> **配套文档：** [UI_Refactoring_Plan.md](./UI_Refactoring_Plan.md) · [ShellMate_BlackBox_TestPlan.md](./ShellMate_BlackBox_TestPlan.md)

---

## 重构总目标

将 ShellMate 从"野蛮生长"的功能堆叠重制为 **零卡顿、极简视觉、完全测试驱动** 的现代 AI-Native 效率终端。核心攻坚方向：

| 目标维度 | 当前痛点 | 重构目标 |
|---------|---------|---------|
| **渲染性能** | `ultraThinMaterial` 多层叠加，GPU 发热卡顿 | 终端区回退纯色；毛玻璃限量仅 Sidebar/Toolbar/弹窗 |
| **架构隔离** | SSH/SFTP/AI 逻辑杂糅在千行 View 闭包中 | 三包分离：Engine / AI / UI；MVVM 严格解耦 |
| **样式规范** | Magic Number 满天飞，DesignTokens 形同虚设 | 100% DesignTokens 收口，零硬编码数值 |
| **可测试性** | UI 无法独立于网络 IO 做单元测试 | 所有业务逻辑移入 ViewModel；View 仅做数据展示 |

**量化 KPI**：重构后，10 SSH 高负荷多任务下 CPU 较当前峰值下降 ≥ 30%；View Body 行数降至 ≤ 400 行；UI 相关单元测试覆盖率提升至 ≥ 60%。

---

## 一、战前分析：三大重灾区（The Targets）

根据代码全盘体检，以下文件是本次重构的首要"手术靶点"：

| 文件 | 当前行数 | 主要问题 | 目标阈值 |
|------|---------|---------|---------|
| `SFTPPanelView.swift` | ~1,269 行 | SFTP 网络 IO、目录刷新、拖拽逻辑全杂糅在 View 内 | ≤ 350 行 |
| `AIAssistantPanelView.swift` | ~1,079 行 | SSE 实时流解码、上下文压栈、OpenAI 协议处理混入 View | ≤ 300 行 |
| `TerminalController.swift` | >1,000 行 | SSH 挂载、NetworkMonitor、SwiftTerm 实例更新无边界 | ≤ 500 行 |
| `ContentView.swift` | 大量 | 全局状态分发、Sheet 呈现混杂在顶层 View 中 | ≤ 200 行 |

> **风险警告**：`TerminalController` 直接承接 `libssh2` 与 `SwiftTerm` 的异步 IO 挂钩，改动时必须保证 `@MainActor` 回调时序不被破坏，否则将导致 TTY 屏幕不刷新的致命闪退。

---

## 二、架构体系升维方案

### 2.1 三包模块化拆分（Swift Package 边界）

按照大重构总纲，将单体 `ShellMate` 主工程拆分为三个独立逻辑层：

```
ShellMate（主工程）
├── ShellMateEngine（纯 Swift/C，无 SwiftUI）
│   ├── libssh2 封装（密钥交换、Socks5、TTY 字节流）
│   ├── SSHConnection / SSH2Connection
│   ├── KnownHostsManager
│   ├── PortForwarder（Local / Remote / SOCKS5）
│   └── SFTPSession / SFTPTransferQueue
│
├── ShellMateAI（纯 Swift，无 SwiftUI）
│   ├── AIService（SSE 流解码、API 报文打解包）
│   ├── CommandSafetyChecker
│   └── HighlightEngine（正则预编译）
│
└── ShellMateUI（SwiftUI 壳，通过 Protocol DI 挂载 Engine/AI）
    ├── 所有 View / ViewModel
    ├── DesignTokens + 共享组件库
    └── Core Data 持久化调度
```

**强制约束**：`ShellMateEngine` 和 `ShellMateAI` 内部文件顶部绝对不允许出现 `import SwiftUI`，违者 PR 打回。

### 2.2 MVVM 边界协议（DI 架构）

引入协议驱动的依赖注入，消灭当前对全局 `@EnvironmentObject` 的过度依赖：

```swift
// 核心服务协议（在 Engine 层定义，UI 层通过 DI 注入）
protocol SFTPServiceProtocol {
    func listDirectory(_ path: String) async throws -> [SFTPEntry]
    func uploadFile(local: URL, remote: String) async throws
    func downloadFile(remote: String, local: URL) async throws
}

protocol LLMServiceProtocol {
    func streamResponse(prompt: String) -> AsyncThrowingStream<String, Error>
}

// BaseViewModel（通用泛型基类）
@MainActor
class BaseViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func handle<T>(_ operation: () async throws -> T) async -> T? {
        isLoading = true
        defer { isLoading = false }
        do {
            return try await operation()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
```

---

## 三、四大 Sprint 实施计划

### Sprint 01 — 削藩与基建（预计 3 天）

**目标**：为接下来的大换血准备好医疗器械，不触碰任何现有功能逻辑。

#### 任务清单

| # | 任务 | 文件 / 产出 | 优先级 |
|---|------|-----------|------|
| S1-01 | 建立 `Core/ViewModels/` 目录结构，新增 `BaseViewModel.swift` | `Core/ViewModels/BaseViewModel.swift` | P0 |
| S1-02 | 定义核心服务 Protocol：`SFTPServiceProtocol`、`LLMServiceProtocol`、`SSHConnectionProtocol` | `Core/Protocols/ServiceProtocols.swift` | P0 |
| S1-03 | 建立 DI 容器（`AppEnvironment`），注入所有服务 Mock/Real 实现 | `Core/DI/AppEnvironment.swift` | P0 |
| S1-04 | **强制清除 Magic Number**：全局搜索 `.padding(\d+)`、`Color(hex:)` 硬编码，统一替换为 `DesignTokens` 调用 | 全工程扫描 | P1 |
| S1-05 | **降级毛玻璃**：`ContentView.swift` 中终端区域 `.background(.ultraThinMaterial)` → `.background(DesignTokens.Colors.surfaceWindow)` | `App/ContentView.swift` | P1 |
| S1-06 | 建立新增文件目录结构：`Shared/Components/`、`Core/Protocols/`、`Core/DI/` | Xcode 工程结构 | P0 |

#### 验收标准
- [ ] 全工程编译通过，零新增 Warning
- [ ] `BaseViewModel` 单元测试可运行（不依赖任何 UI）
- [ ] Instruments - GPU Frame Capture：终端区域无毛玻璃层

---

### Sprint 02 — 边缘换肤（预计 4 天）

**目标**：对风险低的独立面板实施原子化组件改写，跑通 MVVM 样板房流程，不触碰终端核心。

#### 任务清单

| # | 任务 | 文件 / 产出 | 优先级 |
|---|------|-----------|------|
| S2-01 | **新增** `FloatingPanelWrapper` 共用浮动容器 | `Shared/Components/FloatingPanelWrapper.swift` | P0 |
| S2-02 | **新增** `GlassButton`（`variant: .primary / .ghost / .danger`），内聚 Hover/Press 动画 | `Shared/Components/GlassButton.swift` | P0 |
| S2-03 | **新增** `PrimaryGlassButtonStyle` + `GhostButtonStyle`（ButtonStyle 协议） | `Shared/Styles/ButtonStyles.swift` | P1 |
| S2-04 | 重构 `WelcomeScreenView`：抽取 `WelcomeViewModel`，View 行数降至 ≤ 150 行 | `Features/Welcome/` | P0 |
| S2-05 | 重构 `SessionSidebarView`：抽取 `SidebarViewModel`，收拢 CoreData 检索排序逻辑 | `Features/Sidebar/SidebarViewModel.swift` | P0 |
| S2-06 | 重构 `ContentViewToolbar`：按钮全面切换为 `GlassButton` 组件，消灭 inline 样式 | `App/ContentViewToolbar.swift` | P1 |
| S2-07 | **Tab 激活样式**：激活 Tab 顶部增加 `accentPrimary` 2px 高亮线条；未激活 Tab 颜色降至 `textTertiary` | `Features/TabBar/TerminalTabBarView.swift` | P1 |
| S2-08 | **空态对齐**：无会话时显示全英文 "No Active Sessions" 纯净占位页（无装饰 icon）| `Features/Terminal/TerminalEmptyStateView.swift` | P1 |

#### 验收标准
- [ ] `WelcomeViewModel` 和 `SidebarViewModel` 单元测试通过，不依赖 UI
- [ ] 工具栏所有按钮切换至 `GlassButton`，视觉对齐 Figma-Spec-v2 §03
- [ ] Tab 激活/未激活状态视觉对比度通过 Figma 设计稿比对

---

### Sprint 03 — 三大巨石绞杀战（预计 2 周）

**目标**：全员专断重写 SFTP、AI、Terminal 三大超千行怪物，实施 ViewModel 插接，核心逻辑全部剥离出 View。

#### Task A：SFTP 管理面板重构

| # | 任务 | 文件 / 产出 |
|---|------|-----------|
| S3-A-01 | 创建 `SFTPPanelViewModel`：封装目录刷新、上传/下载队列控制、拖拽计算 | `Features/SFTP/SFTPPanelViewModel.swift` |
| S3-A-02 | `SFTPPanelView` 重写：仅持有 `@StateObject var viewModel: SFTPPanelViewModel`，行数 ≤ 350 | `Features/SFTP/SFTPPanelView.swift` |
| S3-A-03 | **UI 翻新**：弃用卡片式毛玻璃列表 → 纯色底 + macOS 原生斑马纹行 / 极简分割线 | `Features/SFTP/SFTPPanelView.swift` |
| S3-A-04 | **UI 翻新**：文件图标改用单色高对比度 SF Symbol，去除旧版彩色图标 | `Features/SFTP/SFTPFileRowView.swift` |
| S3-A-05 | `SFTPPanelViewModel` 单元测试：Mock `SFTPServiceProtocol` 隔离网络 IO | `Tests/SFTPPanelViewModelTests.swift` |

**UI 要求**（来自大重构总纲 §三.A + UI_Design_Review）：
- 文件达 10,000 条时 UI 层级扁平，无额外高斯涂抹
- 使用 `DesignTokens.Colors.surfacePrimary` 纯色底，禁止任何 Material 背景
- 列表使用 macOS 原生 `Table` 或极简 `Divider` 分割线

#### Task B：AI 智能副驾重构

| # | 任务 | 文件 / 产出 |
|---|------|-----------|
| S3-B-01 | 创建 `AIPanelViewModel`：隔离 SSE 实时流解码、上下文记录压栈弹栈、Token 算法 | `Features/AI/AIPanelViewModel.swift` |
| S3-B-02 | `AIAssistantPanelView` 重写：仅持有 `@StateObject var viewModel: AIPanelViewModel`，行数 ≤ 300 | `Features/AI/AIAssistantPanelView.swift` |
| S3-B-03 | **布局升级**：弃用居中阻断式对话框 → **右侧侧滑 Drawer（Trailing Drawer）**，宽度 400px（对齐 Figma-Spec-v2 §09） | `Features/AI/AIAssistantPanelView.swift` |
| S3-B-04 | **代码块样式**：AI 输出的代码高亮区域增加独立 `.background(Color(hex:"#1E1E1E"))`，与外部底色完全切割 | `Features/AI/AICodeBlockView.swift` |
| S3-B-05 | `AIPanelViewModel` 单元测试：Mock `LLMServiceProtocol`，验证 SSE 流解码逻辑 | `Tests/AIPanelViewModelTests.swift` |

**UI 要求**（来自大重构总纲 §三.B + UI_Design_Review）：
- AI 面板必须贴在终端右侧，不阻断终端视线
- 气泡最大宽度 ≤ 80% panel 宽
- Drawer 滑入/滑出使用 `easeInOut(duration: 0.25)` 动效

#### Task C：终端控制器（The Final Boss）

| # | 任务 | 文件 / 产出 |
|---|------|-----------|
| S3-C-01 | 切割 `TerminalController`：将 SSH 挂载 / NetworkMonitor 监听逻辑抽入 `TerminalViewModel` | `Features/Terminal/TerminalViewModel.swift` |
| S3-C-02 | `TerminalController` 瘦身：仅保留 SwiftTerm 实例管理和 TTY 字节流传递，行数 ≤ 500 | `Core/Services/TerminalController.swift` |
| S3-C-03 | 确保 `@MainActor` 时序安全：所有 `SSHEventLoop` → UI 的回调路径保持 `DispatchQueue.main.async` 包裹 | 全链路审查 |
| S3-C-04 | **终端背景降级**：彻底删除 `.background(.ultraThinMaterial)` → 纯色 `DesignTokens.Colors.terminalBackground` | `Features/Terminal/TerminalView.swift` |
| S3-C-05 | `TerminalViewModel` 单元测试：Mock `SSHConnectionProtocol`，验证 `ConnectionState` 状态机流转 | `Tests/TerminalViewModelTests.swift` |

---

### Sprint 04 — QA 黑盒与回归（预计 4 天）

**目标**：防止修复"脂肪堆积"的同时破坏了原有"神经系统"。

#### 任务清单

| # | 任务 | 工具 / 产出 |
|---|------|-----------|
| S4-01 | 人工全量回归：基于 [黑盒测试方案](./ShellMate_BlackBox_TestPlan.md) TC-001 至 TC-010 全部重跑 | 真机测试（192.168.100.167）|
| S4-02 | 断网压测：模拟断网 10 次，验证自动重连与终端 UI 无死锁 | Network Link Conditioner |
| S4-03 | 高频缩放压测：连续调整窗口大小 100 次，验证终端渲染无撕裂/无 GPU 过载 | Instruments - Core Animation |
| S4-04 | 1 万条日志推送压测：验证 `SessionLogStore` + `LogPanelView` 在极限数据量下 UI 不卡顿 | 自定义压测脚本 |
| S4-05 | **CPU 基准对比**：Instruments Time Profiler，记录重构前后 10 SSH 并发下 CPU 峰值，目标下降 ≥ 30% | Instruments - Time Profiler |
| S4-06 | `ultraThinMaterial` 零残留审查：全工程 Grep `.ultraThinMaterial`，确保终端区域无命中 | Grep 审查报告 |
| S4-07 | Magic Number 零残留审查：全工程 Grep `\.padding\([0-9]`，确保无硬编码 padding | Grep 审查报告 |
| S4-08 | 发布 Beta 内测：将重构版本推上 TestFlight，收集 ≥ 5 位极客用户的卡顿反馈 | TestFlight |

#### KPI 验收门禁

| 指标 | 基准值（重构前）| 目标值（重构后）| 判定 |
|------|------------|------------|------|
| 10 SSH 并发 CPU 峰值 | — | 下降 ≥ 30% | 🔲 |
| SFTPPanelView 行数 | ~1,269 | ≤ 350 | 🔲 |
| AIAssistantPanelView 行数 | ~1,079 | ≤ 300 | 🔲 |
| TerminalController 行数 | ~1,000+ | ≤ 500 | 🔲 |
| ViewModel 单元测试覆盖率 | ~0% | ≥ 60% | 🔲 |
| `ultraThinMaterial` 终端区域命中数 | — | 0 | 🔲 |
| Magic Number（裸数字 padding）命中数 | — | 0 | 🔲 |

---

## 四、铁腕纪律要求（PR 合并底线）

在此重构期间及未来，以下几点作为 PR 合并的强制门禁：

1. **业务逻辑零渗漏**：任何 `View` 文件顶部不允许出现 `import libssh2`，不允许包含超过 10 行的非 UI 业务逻辑。
2. **Body 行数配额**：`var body: some View` 闭包内禁止出现 `if-let` 数据组装、网络调用、本地文件 IO。
3. **状态对象配额**：`@State` 仅允许承载本地 UI 临时状态（如 `isHovering`、`isExpanded`），复杂业务状态必须上移至 ViewModel。
4. **DesignTokens 强制执行**：任何硬编码颜色 `Color(hex:)` 或裸数字 `.padding(N)` 一律打回。
5. **Material 限量区**：`.ultraThinMaterial` / `.regularMaterial` 仅允许出现在 Sidebar、Toolbar 以及浮出弹窗的背景层，禁止在终端区域内使用。

---

## 五、关键风险与缓解措施

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| TerminalController 重构破坏 TTY 时序 | 高 | 致命 | 逐函数增量提取，每次提取后真机 TC-001 验证；保留 `@MainActor` 所有回调路径 |
| SFTP 拖拽逻辑迁移至 ViewModel 后 Drop 事件丢失 | 中 | 高 | 保留 View 层 DragGesture/DropDelegate，仅将计算结果通知 ViewModel |
| UIAssistantPanel Drawer 动效与 SplitView 布局冲突 | 中 | 中 | 使用 ZStack + offset 实现 Drawer，不依赖 NavigationSplitView |
| Sprint 03 两周时间内三大模块同时重写，合并冲突风险高 | 高 | 中 | 三个 Task 分配不同工程师，各自在 feature 分支开发，逐模块 Merge |

---

## 六、下一步行动（Next Actions）

- [ ] **即刻**：Lead 工程师创建 `refactor/sprint-01` 分支，建立目录结构与 BaseViewModel 框架
- [ ] **Sprint 01 D1**：全工程运行 Magic Number 扫描脚本，生成清单后逐文件替换
- [ ] **Sprint 01 D2**：建立 DI 容器 `AppEnvironment`，接入 Mock 服务用于单元测试
- [ ] **Sprint 02 D1**：新建 `Shared/Components/FloatingPanelWrapper.swift`，作为所有弹窗的统一外壳
- [ ] **Sprint 03 前**：对 `TerminalController` 执行完整的 `Time Profiler` 快照，留存基准数据
