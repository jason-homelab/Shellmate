# ShellMate 架构优化方案

> **基线文档**：`ShellMate_UE_Review_2026-06-07.md`（UE 评审报告）
> **撰写视角**：资深架构师 / Tech Lead
> **撰写日期**：2026-06-07
> **方案性质**：基于现有 Core/Features/Shared 三层架构的**演进式优化**，非重构
> **目标**：在 **6 周内** 闭环 UE Review 中全部 P0、80% P1 问题，并为 P2 与未来扩展铺路

---

## 0. 架构师视角的总体研判

### 0.1 现状的好与坏

UE Review 列出了 27 条问题，但**根因只有 5 个**：

| 根因 | 表现 | 涉及 UE 问题数 |
|---|---|---|
| **A. 缺横切关注点抽象**（Cross-cutting Concerns） | VoiceOver、Tooltip、Loading 骨架屏散落各处 | 8 |
| **B. 缺反馈通道**（Feedback Channel） | 错误恢复要走完整路径、断网无通知、Toast 缺失 | 6 |
| **C. UI 状态机不显式**（Implicit State Machine） | Tab 关闭无确认、连接状态恢复无入口、Welcome 走完即丢 | 5 |
| **D. 服务发现性弱**（Service Discoverability） | 工具栏图标墙、AI 同意打断、SFTP 入口隐晦 | 5 |
| **E. 大文件 + 状态分散** | TerminalView 1200 行、状态跨 3 层、设置无搜索 | 3 |

**架构判断**：**不需要重构**。Core/Features/Shared 三层 + Service-Repository-Store 模式是健康的。**需要的是补 5 个横切层 + 1 次有针对性的拆分**。

### 0.2 三条架构原则

后续所有改动遵守：

1. **横切下沉**：VoiceOver / Tooltip / 错误恢复 / Loading 形态 → 沉淀到 Shared/Components 与 Modifier 库，**Feature 侧零成本接入**
2. **状态显式化**：所有 UI 状态机用 enum 描述，禁止用 `Bool isLoading + Optional error + Bool isReady` 隐式组合表达
3. **Feature 不直连 Service**：Feature 只依赖 Store 与 Protocol，Service 替换不引起 Feature 改动（已有，强化）

---

## 1. 五个新横切层（核心方案）

### 1.1 横切层 #1：`Accessibility` 模块（解 UE-P0）

**问题定位**：VoiceOver 标签散落 40~50 处需补，分散修改风险高。

**架构方案**：新增 `Shared/Accessibility/` 模块，提供**语义级 Modifier**，业务侧调用语义而非裸 API。

```
Shared/Accessibility/
├── AccessibilityModifiers.swift          // 语义化 modifier 集合
├── AccessibilityCatalog.swift            // 集中管理 label/hint 文案（可 i18n）
├── A11yConnectionStatus.swift            // 连接状态点专用
├── A11yTabSelection.swift                // Tab 选中态专用
└── A11yChatMessage.swift                 // AI 消息气泡专用
```

**关键 API 示例**：

```swift
// 业务侧不再写裸的 accessibilityLabel
SessionStatusDot(status: .connected)
    .a11yConnectionStatus(.connected)   // 一行接入，自动绑定 label + traits + hint

ChatBubble(message: msg)
    .a11yChatMessage(role: msg.role, content: msg.text, timestamp: msg.time)
```

**收益**：
- 40~50 处补丁 → 5 个 modifier 调用 + 1 个 Catalog 维护
- 所有 a11y 文案集中在 Catalog，方便 i18n 同步与文案 review
- 未来增加 Dynamic Type / Reduced Motion 等都从同一入口下发

**实施工作量**：1.5 周（包含全量补齐）

---

### 1.2 横切层 #2：`Feedback` 模块（解 UE-B 通道缺失）

**问题定位**：错误恢复需要 5 步路径回头修改、网络断开无 Notification、Toast 散落。

**架构方案**：建立**统一反馈中枢**，所有用户级反馈（Toast / Notification / Inline Banner / Modal Recovery）走同一管道。

```
Shared/Feedback/
├── FeedbackCenter.swift                  // 全局单例（@MainActor actor）
├── FeedbackChannel.swift                 // 通道枚举：toast/banner/notification/modal
├── FeedbackAction.swift                  // 可恢复操作描述
└── Components/
    ├── ToastHost.swift                   // 顶层 ZStack 注入
    ├── InlineRecoveryBanner.swift        // 终端内的"重试/重输密码"按钮组
    └── SystemNotificationBridge.swift    // 桥接 UNUserNotificationCenter
```

**核心 API**：

```swift
public protocol FeedbackPresenting {
    func present(_ event: FeedbackEvent) async
}

public struct FeedbackEvent {
    let level: Level                       // info / success / warn / error
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let actions: [FeedbackAction]          // [.retry, .editCredentials, .acceptHostKey]
    let channel: FeedbackChannel           // .toast / .banner(.terminal) / .systemNotification
    let lifetime: Lifetime                 // .auto(3s) / .untilDismissed / .untilEventResolved
}

// 业务侧调用
await FeedbackCenter.shared.present(.connectionFailed(
    session: s,
    error: e,
    suggestedActions: [.retry, .editPassword, .testNetwork]
))
```

**FeedbackAction 是关键创新**：
```swift
public enum FeedbackAction {
    case retry(handler: @MainActor () async -> Void)
    case editCredentials(sessionID: UUID)
    case acceptHostKey(fingerprint: String)
    case testNetwork(host: String)
    case dismiss
    case openSettings(tab: SettingsTab)
}
```

每个 Action 自带 handler，FeedbackCenter 渲染时直接绑定按钮，**用户不需要走 5 步回到表单**——错误诊断卡片本身就是操作入口。

**收益**：
- 解 UE-P1#8（错误诊断 Inline 操作）+ UE-P1#9（断网通知）+ UE-P0#3（Tab 误关恢复 ⌘⇧T）一并完成
- 未来加"成功 Toast"（"已复制 SSH 公钥到剪贴板"等）零成本

**实施工作量**：1 周

---

### 1.3 横切层 #3：`UIStateMachine` 模式（解 UE-C 状态分散）

**问题定位**：连接/Tab/Welcome 等状态机用零散 Bool 表达，导致死角（"未连接但又不是失败"、"Welcome 完成后无法回看"）。

**架构方案**：引入轻量级 `StateMachine<S, E>` 协议，关键 UI 状态强制显式建模。

```swift
public protocol UIState: Equatable {
    associatedtype Event
    static var initial: Self { get }
    mutating func reduce(_ event: Event)
}

// 示例：终端连接状态机
public enum TerminalConnectionState: UIState {
    case idle
    case connecting(progress: ConnectStage)
    case connected(since: Date)
    case reconnecting(attempt: Int, lastError: ConnectionError)
    case disconnected(reason: DisconnectReason)
    case failed(error: ConnectionError, recovery: [FeedbackAction])

    public enum Event {
        case connectRequested
        case stageAdvanced(ConnectStage)
        case socketEstablished
        case authSucceeded
        case networkLost
        case userCancelled
        case retryRequested
        case failed(ConnectionError)
    }
}
```

**强制规则**：所有"状态相关 UI 决策"（显示什么按钮、什么颜色、什么文案）从 state 派生：

```swift
extension TerminalConnectionState {
    var displayBadge: BadgeDescriptor { ... }
    var availableActions: [FeedbackAction] { ... }
    var allowsTabClose: TabCloseGuard { ... }   // 解 UE-P0#3
}
```

**首批落地的 5 个状态机**：

| 状态机 | 位置 | 解决 UE 问题 |
|---|---|---|
| `TerminalConnectionState` | Features/Terminal | P1 重连按钮、P1 断网通知 |
| `TabLifecycleState` | Features/TabBar | P0 Tab 误关、⌘⇧T 恢复 |
| `OnboardingFlowState` | Features/Welcome | P1 引导接新建会话、P2 再次显示 |
| `AIConsentState` | Features/AI | P1 同意 Inline 引导 |
| `SettingsDirtyState` | Features/Settings | P1 未保存提醒 |

**收益**：
- UI 派生自唯一真相源 (State)，再不会出现"isLoading=false 但 connection=nil" 的死角
- 测试友好：状态机可以独立单测，覆盖率高
- VoiceOver/Toast/按钮可见性都从同一处派生，根除分歧

**实施工作量**：2 周（含 5 个状态机）

---

### 1.4 横切层 #4：`Discoverability` 模块（解 UE-D 服务发现性）

**问题定位**：高级功能（AI/SFTP/Tmux/隧道）入口埋藏过深，工具栏图标墙等权重。

**架构方案**：建立**能力注册表 + 命令面板 + 引导编排器**三件套。

```
Shared/Discoverability/
├── CapabilityRegistry.swift              // 全局能力注册中心
├── CommandPalette/
│   ├── CommandPaletteView.swift         // ⌘K 命令面板（类 Raycast）
│   └── CommandSearchEngine.swift
├── Onboarding/
│   ├── OnboardingDirector.swift         // Onboarding 编排器
│   ├── OnboardingHint.swift             // Tooltip / Spotlight
│   └── HintTriggerRules.swift           // 何时显示 hint 的规则
└── FeatureBadge/
    └── FeatureBadgeBus.swift             // "新功能"角标管理
```

**CapabilityRegistry 是关键**：

```swift
public struct Capability: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let category: Category                 // .connection / .ai / .productivity / .files
    let icon: SFSymbolName                 // 强制 SF Symbol，配合 UE-P1 图标迁移
    let primaryShortcut: KeyboardShortcut?
    let availability: AvailabilityCondition // 当前会话已连接？AI 已启用？
    let action: @MainActor () -> Void
    let hint: OnboardingHint?              // 关联 Tooltip
}

// App 启动时各 Feature 自注册
CapabilityRegistry.shared.register(.aiAssistant)
CapabilityRegistry.shared.register(.sftpBrowser)
CapabilityRegistry.shared.register(.tmuxManager)
CapabilityRegistry.shared.register(.tunnelManager)
```

**三个 UI 接入点共享同一注册表**：

1. **⌘K 命令面板**：所有能力可搜索（解 UE-P2 设置搜索同源思路）
2. **工具栏重组**：按 category 分组渲染，AI 单独高亮（解 UE-P0#5 图标墙）
3. **OnboardingDirector**：根据用户行为（首次连接成功 / 7 天未用 AI）触发 hint（解 UE-P1#6 引导接新建会话）

**收益**：
- 新增功能只需注册到 Registry，工具栏 / 命令面板 / Onboarding 自动包含
- AI 这种核心能力可以通过 `category: .ai` + 工具栏特殊渲染规则做视觉突出
- ⌘K 是"图标墙"的根治方案：再多功能也只是一个搜索框的距离

**实施工作量**：2 周（含 ⌘K 面板 + 工具栏重组）

---

### 1.5 横切层 #5：`LoadingPresentation` 模块（解 UE-P1#15 骨架屏）

**问题定位**：所有 Loading 都用 `ProgressView()` 旋转，无骨架屏，加载长时无反馈。

**架构方案**：定义统一的 Loading 形态分级。

```swift
public enum LoadingPresentation {
    case skeleton(rows: Int, style: SkeletonStyle)    // 列表场景
    case shimmer(layout: ShimmerLayout)                // 卡片场景
    case spinner(label: String?)                       // 短任务
    case progress(percent: Double, label: String)      // 已知进度
    case inline(text: String)                          // 输入栏右侧"AI 思考中..."
}

// SwiftUI 包装
struct LoadingContainer<Content: View>: View {
    let state: LoadStatus<Content.Output>
    let presentation: LoadingPresentation
    @ViewBuilder let content: (Output) -> Content
}
```

```
Shared/Components/Loading/
├── LoadingContainer.swift
├── Skeleton/
│   ├── SkeletonRow.swift                 // 通用列表行骨架
│   ├── SkeletonSidebar.swift             // 侧边栏专用
│   └── SkeletonFileRow.swift             // SFTP 文件行专用
└── Shimmer.swift
```

**业务侧调用**：
```swift
LoadingContainer(state: viewModel.fileListState, 
                 presentation: .skeleton(rows: 8, style: .fileRow)) { files in
    SFTPFileListView(files: files)
}
```

**收益**：5 处主 Loading 场景统一升级，加载感知质感跃升

**实施工作量**：1 周

---

## 2. 一次有针对性的拆分：`TerminalView.swift`

### 2.1 拆分原则

**不做大重构**。1200 行不是问题，**关注点混合**才是。当前 TerminalView 同时承担：

- 终端渲染包装（SwiftTerm Representable）
- 工具栏（已部分拆出）
- 多面板布局（Compose / SFTP / Search Overlay）
- 字体/主题应用
- 连接状态展示
- 错误覆层

**目标**：拆成 5 个 ≤300 行的纯展示组件 + 1 个 Container。

### 2.2 拆分蓝图

```
Features/Terminal/
├── TerminalView.swift                    [Container, ~200 行]
│   └── 仅负责状态机绑定 + 子视图组装
├── Rendering/
│   ├── SwiftTermRepresentable.swift     [已存在]
│   └── TerminalThemeApplier.swift       [新, ~150 行]
│       └── 颜色/字体应用从 TerminalView 抽出
├── Layout/
│   ├── TerminalPanelLayout.swift        [新, ~200 行]
│   │   └── 主终端 + Compose + SFTP 三栏弹性布局
│   └── SFTPSlidePanel.swift             [新, ~120 行]
├── Overlay/
│   ├── SearchOverlay.swift              [已部分存在, 整理至 ~150 行]
│   ├── ConnectionStateOverlay.swift     [新, ~180 行]
│   │   └── 显示 重连按钮 / 错误诊断 (绑定 TerminalConnectionState)
│   └── PasteGuardOverlay.swift          [新, ~80 行]
│       └── 解 UE-P1#18 多行粘贴危险检测
└── State/
    └── TerminalConnectionState.swift    [新, ~150 行]
        └── 见 1.3 节状态机
```

**收益**：
- TerminalView 从 1200 → ~200 行，可读性极大提升
- 每个组件可独立预览（SwiftUI Preview）和单测
- 解 UE-P1#16 重连按钮（在 ConnectionStateOverlay 绑定 state.availableActions）
- 解 UE-P1#18 粘贴检测（PasteGuardOverlay 独立模块，可单测）

**实施工作量**：1.5 周（拆分 + 回归测试）

**风险点**：
- SwiftTerm Representable 与 SwiftUI 状态绑定边界要明确
- 字体/主题应用涉及 NSTextStorage 直接操作，单测难，需 UI 测试覆盖

---

## 3. 三个关键基础设施补强

### 3.1 SF Symbols 迁移（解 UE-P1#17 + 配套 a11y）

**问题**：当前工具栏用 Unicode 字符（⏻ ✦ </>），多语言下字宽风险 + 无 a11y。

**方案**：

```swift
// Shared/Iconography/AppIcon.swift
public enum AppIcon: String {
    case connect = "power.circle.fill"
    case ai = "sparkles"
    case script = "chevron.left.forwardslash.chevron.right"
    case sftp = "folder.fill"
    case tunnel = "arrow.left.arrow.right.circle"
    // ...

    public var image: Image { Image(systemName: rawValue) }
    public var a11yLabel: LocalizedStringKey { /* from AccessibilityCatalog */ }
}

// 业务侧
Button { ... } label: { AppIcon.ai.styledLabel("AI 助手") }
```

**配套规则**：
- 禁止业务代码出现 `Image(systemName: ...)` 字面量，必须经 `AppIcon`
- 通过 SwiftLint 自定义规则 + PR Checklist 守护

**收益**：图标 / a11yLabel / Tooltip 三位一体，单点替换，**自然解 UE-P0#1（VoiceOver）和 UE-P1#17（图标墙）**

**实施工作量**：1 周（含全量替换）

---

### 3.2 Connection Preflight 服务（解 UE-P0#2 测试连接）

**问题**：表单提交前无法验证配置。

**方案**：在 `Core/Services/SSH/` 新增独立 `ConnectionPreflightService`，与正式连接服务解耦。

```swift
public protocol ConnectionPreflightServicing {
    func preflight(_ profile: SessionProfile) async -> PreflightResult
}

public struct PreflightResult {
    let stages: [PreflightStage: StageOutcome]
    // .dnsResolution / .tcpReachability / .sshHandshake / .authentication
    let summary: Summary    // .success / .failedAt(stage, error)
    let suggestedActions: [FeedbackAction]   // 复用 FeedbackAction，与 1.2 联动
    let elapsedMs: Int
}
```

**关键设计**：
- **分阶段返回**：DNS → TCP → SSH 握手 → 认证，每阶段单独显示绿勾 / 红叉，用户清楚哪步失败
- **不打开终端会话**：preflight 后立即释放连接，不占用资源
- **复用诊断引擎**：与 `ConnectionErrorAnalysis` 共享错误分类逻辑（已有，扩展）

**UI 接入**：
- `SessionFormSheet` 底部加 "测试连接" 次按钮
- 点击后表单下方展开 `PreflightProgressView`（4 行 stage 列表，逐项 animate）

**收益**：
- 解 UE-P0#2
- 副产品：未来"批量健康检查"（用户多会话场景）天然有 API 支持

**实施工作量**：1 周

---

### 3.3 Settings Search Index（解 UE-P1#13 设置搜索）

**问题**：设置项 50+，分 8 Tab，搜索缺失。

**方案**：引入 `SettingsIndex` 元数据系统。

```swift
public struct SettingItem {
    let id: String
    let title: LocalizedStringKey
    let keywords: [LocalizedStringKey]    // 别名（"心跳" / "keepalive" / "保活"）
    let tab: SettingsTab
    let section: String
    let renderer: () -> AnyView           // 高亮跳转用
}

// 每个 SettingsView 自注册
SettingsIndex.register([
    SettingItem(id: "cursor.blink", title: "光标闪烁", 
                keywords: ["cursor", "blink", "光标"],
                tab: .appearance, section: "光标"),
    // ...
])

// 设置面板顶部
SettingsSearchBar()   // 输入 → 实时定位 Tab + Section + 临时高亮
```

**架构亮点**：
- 与 1.4 的 CapabilityRegistry **同构**——都是"自注册 + 集中检索"模式
- 未来可合并到 ⌘K 命令面板（"快捷键设置" 直接搜到）

**实施工作量**：3 天

---

## 4. 端到端方案 vs UE Review 问题映射

| UE Review 问题编号 | 优先级 | 架构方案 | 涉及横切层 |
|---|---|---|---|
| P0#1 VoiceOver 缺失 | P0 | §1.1 Accessibility + §3.1 SF Symbols | A11y + Icon |
| P0#2 测试连接按钮 | P0 | §3.2 ConnectionPreflightService | Preflight |
| P0#3 Tab 误关保护 + ⌘⇧T | P0 | §1.3 TabLifecycleState + §1.2 Feedback | StateMachine + Feedback |
| P0#4 BUG-002 双击冒泡 | P0 | TerminalView 拆分阶段顺带修复 | Refactor |
| P0#5 工具栏图标墙 | P0 | §1.4 CapabilityRegistry + §3.1 SF Symbols | Discoverability + Icon |
| P1#6 欢迎引导接新建会话 | P1 | §1.3 OnboardingFlowState + §1.4 OnboardingDirector | StateMachine + Discoverability |
| P1#7 示例会话/演示模式 | P1 | OnboardingDirector 内置 demo seed | Discoverability |
| P1#8 错误诊断 Inline 操作 | P1 | §1.2 FeedbackAction | Feedback |
| P1#9 网络断开 macOS 通知 | P1 | §1.2 SystemNotificationBridge | Feedback |
| P1#10 密码"按住显示" | P1 | Shared/Components/SecureFieldExt | Component |
| P1#11 分组下拉新建分组 | P1 | FormComponents 扩展 InlineCreatable | Component |
| P1#12 AI 隐私 Inline 引导 | P1 | §1.3 AIConsentState | StateMachine |
| P1#13 设置搜索框 | P1 | §3.3 SettingsIndex | Infra |
| P1#14 设置未保存提醒 | P1 | §1.3 SettingsDirtyState | StateMachine |
| P1#15 骨架屏 | P1 | §1.5 LoadingPresentation | Loading |
| P1#16 终端"重连"按钮 | P1 | §2.2 ConnectionStateOverlay 绑定 §1.3 | StateMachine + Refactor |
| P1#17 Unicode → SF Symbols | P1 | §3.1 AppIcon | Icon |
| P1#18 多行粘贴检测 | P1 | §2.2 PasteGuardOverlay | Refactor |
| P2#19~27 其他精致度 | P2 | 借势横切层一并解决 | 复用 |

**结论**：5 个横切层 + 3 个基础设施 + 1 次拆分 = **闭环 27 个 UE 问题中的 24 个**，剩余 3 个为 P2 文案/性能基准，独立处理。

---

## 5. 实施路线图（6 周交付）

### 5.1 阶段划分

```
W1-W2  [Foundation]     横切层 #1 #2 #3（A11y + Feedback + StateMachine）
                         不影响业务功能，全员可并行
W3     [Discoverability] 横切层 #4 + SF Symbols 迁移
                         可见的工具栏重组开始
W4     [Polish]         横切层 #5 LoadingPresentation + ConnectionPreflight
                         "测试连接"按钮上线
W5     [Refactor]       TerminalView 拆分 + Overlay 落地
                         重连按钮、粘贴守护上线
W6     [Integration]    SettingsSearch + Onboarding 编排 + 回归测试
                         全量 a11y 复检
```

### 5.2 关键里程碑与可演示成果

| 周次 | Demo 成果（面向 PM/Stakeholder） |
|---|---|
| W2 末 | 连接失败 → 红色 banner 含"重新输入密码"按钮，点击直接打开 Inline Sheet |
| W3 末 | ⌘K 命令面板可搜索所有功能；工具栏 AI 按钮独立高亮 |
| W4 末 | 新建会话表单"测试连接" → 显示 4 阶段进度条 + 失败建议 |
| W5 末 | 终端断开后中央显示大号"重新连接"按钮 + 倒计时 |
| W6 末 | 设置面板搜索"心跳"瞬间定位；首次启动引导第 3 步直接打开 SessionFormSheet |

### 5.3 资源需求

- **iOS/macOS 工程师**：2 人（Foundation 与 Refactor 各 1，W3 后并入业务）
- **设计师协助**：W3、W5 各 2 天（图标重审、Overlay 视觉对齐 Figma）
- **QA**：W5、W6 全程；W2 末横切层单测覆盖审计

### 5.4 不在本期范围

- P2#23 英文文案母语者 review（外协，并行）
- P2#26 大数据性能基准（独立项目，下个季度）
- 完整 AI 流式响应优化（已工作，不在本方案范围）

---

## 6. 质量守护：架构级护栏

为防止"做完后劣化"，配套引入以下机制：

### 6.1 代码层护栏

| 护栏 | 工具 | 守护对象 |
|---|---|---|
| 禁止 `Image(systemName:)` 字面量 | SwiftLint custom rule | SF Symbols 强制走 AppIcon |
| 禁止 `Color(hex: "#...")` 字面量（除 Token 文件） | SwiftLint custom rule | 防止硬编码颜色回潮 |
| 禁止 `.accessibilityLabel(literal)` 业务侧出现 | SwiftLint custom rule | A11y 文案走 Catalog |
| `.animation(.easeInOut(duration:))` 必须用 Token | SwiftLint custom rule | 动画时长 Token 化 |
| TerminalView.swift ≤ 300 行 | CI 文件行数检查 | 防止拆分后再次膨胀 |

### 6.2 测试层护栏

- **状态机单测**：5 个新状态机各 ≥80% 行覆盖率（状态机天生测试友好）
- **A11y 快照测试**：关键视图用 XCUITest 验证 VoiceOver label 输出
- **Feedback 集成测试**：模拟 5 类错误，验证 banner / toast / system notification 三通道触发

### 6.3 流程层护栏

- **PR 模板新增 a11y/feedback/state-machine 三项 checklist**
- **每周架构 sync 30 分钟**：横切层接入情况通报
- **W6 末做一次 a11y 全量回归**（VoiceOver 真机走查所有主路径）

---

## 7. 风险登记表（Risk Register）

| 风险 | 概率 | 影响 | 缓解策略 |
|---|---|---|---|
| TerminalView 拆分引入 SwiftTerm 渲染回归 | 中 | 高 | W5 前完成 UI 测试基线；拆分分 2 个 PR 推进，先 layout 后 overlay |
| Feedback 中枢与现有 Alert 共存期混乱 | 中 | 中 | W1 制定 Feedback 与 Alert 迁移规则文档；老 Alert 逐场景迁移而非一刀切 |
| ⌘K 命令面板抢占系统快捷键冲突 | 低 | 中 | W3 上线前测试 Spotlight / Finder 行为；提供设置项允许自定义快捷键 |
| Preflight 连接占用与正式连接资源冲突 | 低 | 中 | Preflight 用独立 Socket，超时 5s 强制释放；不复用 SSHConnectionManager |
| SF Symbols 在 macOS 13 渲染不一致 | 低 | 低 | 选用 SF Symbols 4.0 以下符号；最低部署目标已设 13.0 |
| 横切层重构期与日常需求并行人力不足 | 高 | 中 | W1-W2 暂停新 feature 排期；横切层提供后日常需求基于其开发 |

---

## 8. 关键决策记录（ADR 摘要）

为后续团队成员理解，在 `docs/adr/` 下沉淀 5 个 ADR：

- **ADR-001**: 为何不重构而是补横切层（架构债判断与演进策略）
- **ADR-002**: FeedbackCenter 采用 @MainActor actor 而非 ObservableObject 的理由
- **ADR-003**: UI 状态机为何手写 enum 而非引入 TCA / Combine reducer
- **ADR-004**: CapabilityRegistry 选择运行时注册 vs 编译时配置的权衡
- **ADR-005**: SF Symbols 全量迁移与 Unicode 共存期的过渡策略

---

## 9. 长期视图（6 个月后）

完成本期 6 周方案后，ShellMate 将具备：

- **5 个横切层** 成为新功能开发的标准底座
- **CapabilityRegistry** 让"新增高级功能"边际成本降至**只需注册一行**
- **状态机模式** 普及到 3~5 个新业务领域（SFTP 传输队列、AI 对话生命周期、Tmux 会话状态等）
- **a11y / 性能 / 错误恢复** 成为 Definition of Done 的硬指标

**下一阶段架构重点**（不在本方案范围，仅供规划）：

1. **多窗口架构**：当前是单 Window，未来多 Window 需要 SceneStorage + 跨窗口状态同步
2. **插件化 / 脚本扩展生态**：基于 CapabilityRegistry 演进为第三方扩展宿主
3. **协作功能**：会话共享、配置共享 → 引入 CRDT 或 OT 架构
4. **大规模性能**：终端虚拟化、SFTP 文件分页、CoreData 千级会话场景

---

## 10. 一句话总结

> ShellMate 当前架构是 **"健康但散"**——不需要推倒，需要**收口**。
> 用 **5 个横切层 + 1 次拆分 + 3 个基础设施**，在 6 周内同时闭环 24 个 UE 问题、把 27 个分散的体验债务变成 5 个可观测、可测试、可迭代的统一治理面。

---

**架构师**：Claude（代理资深架构师视角）
**关联文档**：
- `ShellMate_UE_Review_2026-06-07.md`（问题输入）
- `技术方案.md` v3.0（架构基线）
- `开发进度.md`（资源排期协调）
**版本**：v1.0
