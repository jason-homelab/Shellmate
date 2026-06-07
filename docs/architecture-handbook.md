# ShellMate 架构维护手册

> **作用**：W6 交付。后续团队成员理解、扩展、维护横切层的入口文档。
> **基线版本**：commit `8f3331c` 之后
> **关联**：`docs/adr/ADR-001` 至 `ADR-005` / `docs/design-specs/W0_设计规格统一交付.md`

---

## 1. 横切层全景

| 层 | 位置 | 入口 | ADR | 解决的 UE 问题 |
|---|---|---|---|---|
| Accessibility | `Shared/Accessibility/` | `AccessibilityCatalog` + 5 语义 modifier | — | UE-P0#1 |
| Feedback | `Shared/Feedback/` | `FeedbackCenter.shared.present(_:)` | ADR-002 | UE-P1#8 / #9 |
| UI 状态机 | `Shared/StateMachine/` | `UIState` protocol + 5 状态机 | ADR-003 | UE-P0#3 / P1#12 / #14 / #16 |
| Discoverability | `Shared/Discoverability/` | `CapabilityRegistry.shared.register(_:)` | ADR-004 | UE-P0#5 |
| Iconography | `Shared/Iconography/AppIcon.swift` | `AppIcon` enum | ADR-005 | UE-P1#17 |
| Loading | `Shared/Components/Loading/` | `LoadingContainer<Value, ...>` | — | UE-P1#15 |

3 个基础设施：
- **`Core/Services/SSH/ConnectionPreflightService`** — 测试连接（UE-P0#2）
- **`Features/Settings/SettingsIndex`** — 设置搜索（UE-P1#13）
- **`Shared/Iconography/AppIcon`** — 同上

1 套独立 Overlay：
- **`Features/Terminal/Overlay/`** — ConnectionStateOverlay / PasteGuardOverlay / PasteGuardAnalyzer

---

## 2. 横切层接入指南

### 2.1 Feedback：报告一个错误 / 成功 / 警告

**Toast（短时自动消失）**：
```swift
FeedbackCenter.shared.present(.success("操作完成"))
FeedbackCenter.shared.present(.info("已复制到剪贴板"))
```

**Banner（持续显示，含恢复操作）**：
```swift
FeedbackCenter.shared.present(.error(
    "连接失败",
    message: "认证错误，请检查凭据",
    actions: [
        .editCredentials { /* 弹出编辑表单 */ },
        .retry { /* 重新连接 */ }
    ],
    bannerSlot: .terminal
))
```

**系统通知（App 在后台时）**：
```swift
FeedbackCenter.shared.present(FeedbackEvent(
    level: .warn,
    title: "网络已断开",
    channel: .systemNotification
))
```

### 2.2 Accessibility：为新组件加 VoiceOver 标签

**禁止**：`.accessibilityLabel("已连接")` 字面量（SwiftLint 会警告）

**推荐**：
```swift
// 1. 在 AccessibilityCatalog 加 key + 在 Localizable.strings 加翻译
// 2. 业务侧用语义 modifier
StatusDotView(state: .connected)
    .a11yConnectionStatus(.connected)

ChatBubble(message: msg)
    .a11yChatMessage(role: msg.role, content: msg.text)
```

### 2.3 状态机：为业务领域引入 UI 状态

**步骤**：
1. 在 `Shared/StateMachine/` 新建 `<Domain>State.swift`
2. 实现 `UIState` 协议（含 `Event` enum、`initial`、`reduce(_:)`）
3. 在业务视图中：`@StateObject var sm = StateMachine<MyState>()`
4. UI 渲染从 `sm.state` 派生，事件用 `sm.send(.foo)`

**经验法则**：
- 每个状态机 ≤ 10 态；超出说明该拆分
- 派生的 UI 属性（icon / title / color）以 `extension <State>` 形式放同文件
- 状态机自带单测义务（见 §3.1）

### 2.4 Discoverability：新增高级功能时

```swift
// 在 Feature 的 Bootstrap 或 App init 时调用
CapabilityRegistry.shared.register(Capability(
    id: "files.sftp.advanced",
    title: "高级 SFTP 选项",
    category: .files,
    icon: .sftp,
    shortcut: .init(key: "S", modifiers: "⌘⌥"),
    searchTokens: ["sftp", "advanced", "高级", "选项"],
    isAvailable: { /* 当前会话已连接 */ },
    action: { /* 打开高级面板 */ }
))
```

此后该能力**自动出现在 ⌘K 命令面板、工具栏（按 category 渲染时）、OnboardingDirector 推荐池**——零额外接入。

### 2.5 Iconography：新增图标

1. 选符：去 SF Symbols App 选，**限定 SF Symbols 4.0 内**（macOS 13 兼容）
2. 在 `AppIcon` enum 加 case + a11yLabel
3. 业务侧调用 `AppIcon.<case>.image` 或 `.render(size:weight:)`

**禁止**：`Image(systemName: "...")` 字面量（SwiftLint 警告）

### 2.6 Loading：标准化加载态

```swift
LoadingContainer(
    status: viewModel.fileListStatus,
    presentation: .skeleton(rows: 8, style: .fileRow)
) { files in
    SFTPFileListView(files: files)
} empty: {
    EmptyStateView.noFiles
}
```

5 种 presentation：
- `.skeleton(rows: Int, style:)` — 列表骨架（4 样式）
- `.shimmer(layout:)` — 卡片骨架（3 布局）
- `.spinner(label:)` — 短任务旋转圈
- `.progress(percent:, label:)` — 已知进度
- `.inline(text:)` — 输入栏右侧 "AI 思考中..."

---

## 3. 测试约定

### 3.1 状态机单测覆盖率要求

每个状态机 ≥ 80% 行覆盖率。模板：

```swift
final class TerminalConnectionStateTests: XCTestCase {
    func test_idle_to_connecting() {
        var state = TerminalConnectionState.idle
        state.reduce(.connectRequested)
        XCTAssertEqual(state, .connecting(stage: .dns))
    }

    func test_reconnecting_max_attempts() { /* ... */ }
    func test_connected_to_failed_authentication() { /* ... */ }
}
```

### 3.2 Analyzer 单测

`PasteGuardAnalyzer` 是纯逻辑模块，建议单测覆盖 16 项危险关键词命中 + 3 级 GuardLevel 边界。

### 3.3 a11y 快照测试

关键视图（SessionRowView、TabBar、AI 消息气泡）用 XCUITest 验证 VoiceOver 输出，作为 W6 真机回归的自动化补充。

---

## 4. SwiftLint 5 条护栏

`.swiftlint.yml` 已配置以下规则。**违反必须修复或显式 disable + 注释说明**：

| 规则 | 守护目标 |
|---|---|
| `raw_sf_symbol` | 禁止 `Image(systemName: "...")` — 走 AppIcon |
| `raw_hex_color` | 禁止业务侧 `Color(hex: "#...")` — 走 DesignTokens |
| `raw_a11y_label` | 禁止 `.accessibilityLabel("...")` 字面量 — 走 Catalog |
| `raw_animation_duration` | 禁止 `.easeInOut(duration: X)` — 走 Animation Token |
| `terminal_view_size` | TerminalView.swift ≤ 300 行 — 防止再次膨胀 |

CI 阶段（建议）：`swiftlint --strict` 阻塞 PR。

---

## 5. Token 系统命名空间分层

```
DesignTokens
├── Colors        — 原子层（surface、glass、text、accent、status）
├── Typography    — 字体（含 Mono 子命名空间，W1 新增）
├── Spacing       — nano (2pt) → xxl (32pt)
├── Sizes         — corner radius / sidebar width / icon size
├── Animation     — fast/standard/medium/slow/spring/glass/hover（7 档）
├── Shadow        — 旧阴影系统（small/medium/large/xlarge）
├── Gradients     — 玻璃边框 / accent button / AI / Welcome（W1 扩展）
├── Semantic      — W1 新增：feedback 4 色 + tunnel 3 色 + focusRing
└── Elevation     — W1 新增：e0-e4 + 深色内描边补偿
```

**接入约定**：
- 品牌触点 → `accent*`（Apple Blue）
- 反馈语义 → `Semantic.feedback*`
- 浮层层级 → `Elevation.e1` 起步
- 等宽数据 → `Typography.Mono.dataXS/SM/code/label`

---

## 6. 既知技术债（W7+ Backlog）

按优先级排序：

### 🔴 高优先级（下个 Sprint）
1. **TerminalView.swift 1200 → 300 行拆分**（W5 推迟项）
   - Phase 1: 抽出 `TerminalPanelLayout` + `TerminalThemeApplier`
   - Phase 2: 抽出 `ConnectionStateOverlay` / `PasteGuardOverlay` 业务接入
   - Phase 3: 状态从 30+ @State 集中至 `TerminalConnectionState` 状态机
   - 必须配套 SwiftTerm 渲染 UI 测试基线

2. **Command Palette UI 实现**（W3 推迟项）
   - `CapabilityRegistry` 已就绪
   - 需开发 `CommandPaletteView`（580pt 浮窗 + 5 态 + ⌘K 触发）
   - 触发 `.toggleCommandPalette` Notification 已埋点

3. **工具栏重组**（W3 推迟项）
   - `ContentViewToolbar` AI 按钮加渐变高亮
   - 「工具▾」收纳菜单 + ⌘K 横条
   - 智能折叠（窗口 ≤ 1200pt）

### 🟡 中优先级
4. **SSH 握手 + 认证阶段的 Preflight 实现**
   - `ConnectionPreflightService` 目前仅 DNS + TCP，SSH 阶段 `.skipped`
   - 需复用 `SSHConnectionManager` 的 libssh2 桥接（独立 socket，5s 超时强制释放）

5. **Image(systemName:) 全量替换为 AppIcon**（W8 部分完成）
   - AppIcon enum 已扩展至 75 个 case（W8）
   - 已迁移 ~31 处高可见度文件：StatusBar / TerminalView / SessionFormSheet /
     AIAssistantPanel / SecuritySettingsView
   - 剩余 ~239 处分散各业务文件，SwiftLint raw_sf_symbol 持续守护
   - 后续 PR 按文件迁移即可，AppIcon 已覆盖 75 个常用 SF Symbol

6. **Feedback Action handler 全量接入**
   - 5 类 handler（retry / editCredentials / acceptHostKey / testNetwork / openSettings）
   - 各 Feature 团队认领接入到自身错误处理路径

### 🟢 低优先级（精致度）
7. Onboarding 第 3 步接入新建会话流程
8. 首次启动注入示例会话
9. 设置面板搜索 UI（`SettingsIndex` 已就绪，缺顶部搜索框 UI）
10. AI 同意 Inline 引导（`AIConsentState` 已就绪，缺 UI）

---

## 7. 谁是这些代码的负责人

| 区域 | 主负责人 | 备份 |
|---|---|---|
| Accessibility 模块 | TBD | TBD |
| Feedback 模块 | TBD | TBD |
| 5 套状态机 | TBD | TBD |
| CapabilityRegistry | TBD | TBD |
| AppIcon | TBD | TBD |
| ConnectionPreflightService | TBD | TBD |

> 待团队 owner 分配后填入。Tech Lead 兜底，每周架构 sync 30 min。

---

## 8. 路标：什么时候应该升级到 v2

本期横切层是 **v1 演进式补齐**。以下信号触发 v2 重构讨论：

- 状态机数量 ≥ 12 → 考虑引入 TCA / Reducer 模式（重新评估 ADR-003）
- 单一 Feature 直接依赖 ≥ 4 个横切层 → 考虑 Feature Bootstrap 抽象
- 多窗口 / 多设备协作需求确定 → 重构 FeedbackCenter 为 actor + Channel 路由
- 第三方插件生态启动 → CapabilityRegistry 加入运行时签名与权限模型

---

**手册版本**：v1.0 @ 2026-06-07
**下次更新触发**：横切层新增 / SwiftLint 规则变化 / Backlog 关键项关闭
