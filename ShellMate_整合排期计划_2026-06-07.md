# ShellMate 整合排期计划

> **整合来源**：
> - `ShellMate_UE_Review_2026-06-07.md`（27 个用户体验问题，P0×5 / P1×13 / P2×9）
> - `ShellMate_架构优化方案_2026-06-07.md`（5 横切层 + 3 基础设施 + 1 拆分）
> - `ShellMate_UI_Self_Review_2026-06-07.md`（6 套组件视觉规格 + 3 套 Token 命名空间）
>
> **撰写日期**：2026-06-07
> **计划周期**：W0（准备周）+ W1-W6（执行周）= **7 个自然周**
> **起算日**：2026-06-08（W0 周一）→ 2026-07-26（W6 周日）
> **可调度人力**：iOS 工程师 ×2、UI 设计师 ×1、QA ×1、Tech Lead ×0.5、PM ×0.3

---

## 0. 整合视图（一张图看全貌）

### 0.1 三轨并行总览

```
周次   W0    W1    W2    W3    W4    W5    W6
日期   6/08  6/15  6/22  6/29  7/06  7/13  7/20
────────────────────────────────────────────────────────────
设计   ████  ▓▓▓▓  ▓▓▓▓  ▓▓▓▓  ▓▓▓▓  ▓▓▓▓  ▓▓▓▓
       Figma  状态  态势  工具  Pre   Conn  a11y
       Token  矩阵  对齐  栏    flight Over  走查
       6组件        AppI  重组              lay
────────────────────────────────────────────────────────────
架构         ████  ████  ▓▓▓▓  ▓▓▓▓
             A11y  State Disc  Pre
             FB    Mach  over  flight
             横切                Load
────────────────────────────────────────────────────────────
重构                            ████  ████
                                Term  Conn
                                inal  Over
                                拆分  lay
────────────────────────────────────────────────────────────
完善                                  ████  ████
                                      Pas   Set
                                      te    Sea
                                      Grd   rch
────────────────────────────────────────────────────────────
QA                                    ▓▓▓▓  ████
                                      a11y  全量
                                      回归  回归
────────────────────────────────────────────────────────────

█ = 主线工作   ▓ = 配合/审阅
```

### 0.2 关键路径（Critical Path）

> W0 Figma Token + Feedback/Palette/AppIcon 规格
>  → W1 Accessibility + Feedback 横切层
>  → W3 SF Symbols 全量迁移
>  → W5 TerminalView 拆分 + ConnectionStateOverlay
>  → W6 全量 a11y 回归

**关键路径上任何任务延期 > 2 天必须升级 Tech Lead 决策**。

---

## 1. 角色 RACI 矩阵

| 维度 | iOS-A (Foundation) | iOS-B (Feature) | UI 设计师 | QA | Tech Lead | PM |
|---|---|---|---|---|---|---|
| 横切层 #1-#5 | R | C | C | I | A | I |
| 基础设施 #1-#3 | C | R | C | I | A | I |
| TerminalView 拆分 | C | R | C | R | A | I |
| Figma Token / 组件 | I | I | R | I | C | A |
| a11y 走查 | C | C | R | R | A | I |
| 里程碑评审 | C | C | C | I | A | R |

R=负责执行 / A=审批 / C=咨询 / I=知会

---

## 2. 任务清单（按周 × 编号化）

### 任务 ID 编码

`[周次]-[角色]-[序号]`，例：`W2-iOS-A-03`
- 角色：DSN(设计)/iOS-A(基础)/iOS-B(业务)/QA/TL(架构)/PM

### 来源标签

- `[UE-P0#X]` = UE Review 问题编号
- `[ARCH §X.X]` = 架构方案章节
- `[UI §X.X]` = UI 自评章节

---

## W0：设计冲刺周（2026-06-08 → 06-14）

> **W0 主旨**：UI 必须先于代码完成 Token + 6 套组件视觉规格，否则 W1-W2 的 Foundation 编码将"视觉真空"。

### W0-DSN-01 ✦ 三套新 Token 命名空间在 Figma 定稿
- **来源**：[UI §1.2 / §4.4 / §5]
- **内容**：Semantic（feedback 4 色 / tunnel 3 色 / status 4 态）、Elevation（e0-e4 ×亮/深）、Gradient（welcome / AI / accent）、Typography mono 子集
- **产出**：Figma `Tokens / Semantic`、`Tokens / Elevation`、`Tokens / Gradient`、`Tokens / Typography Mono` 4 个 Page
- **工时**：3 d
- **依赖**：无
- **验收**：Tech Lead + UI 共同 review，确认 hex 值、命名、亮/深对齐

### W0-DSN-02 ✦ AppIcon SF Symbols 全量映射表
- **来源**：[UE-P1#17 / ARCH §3.1 / UI §3.5]
- **内容**：10+ 图标的 symbol 选型 + 视觉重量 + AI 渐变规则 + fallback 表（macOS 13 兼容）
- **产出**：Figma `Components / AppIcon` + 一份 Markdown 映射表交付 iOS-A
- **工时**：1.5 d
- **依赖**：W0-DSN-01（颜色 Token）

### W0-DSN-03 ✦ FeedbackBanner / Toast 4 level 视觉规格
- **来源**：[UE-P1#8 #9 / ARCH §1.2 / UI §3.1]
- **内容**：Toast×4 + Banner×4 + 多 Toast 堆叠规则 + 动效规格（spring 参数、入出场时长）
- **产出**：Figma `Components / Feedback` + 动效参数文档
- **工时**：1.5 d
- **依赖**：W0-DSN-01

### W0-DSN-04 ✦ Command Palette 视觉主屏
- **来源**：[UE-P0#5 / ARCH §1.4 / UI §3.2]
- **内容**：默认/聚焦/搜索/无结果/AI 增强 5 态 + 行变体 + 入场动效
- **产出**：Figma `Components / Command Palette`
- **工时**：2 d
- **依赖**：W0-DSN-01, W0-DSN-02

### W0-DSN-05 ✦ Skeleton 三套蓝图 + shimmer 帧
- **来源**：[UE-P1#15 / ARCH §1.5 / UI §3.4]
- **内容**：SkeletonSidebar / SkeletonFileRow / SkeletonCard + 1400ms shimmer + 80ms 错峰规则
- **产出**：Figma `Components / Skeleton`
- **工时**：1 d
- **依赖**：W0-DSN-01

### W0-TL-01 ✦ ADR 撰写（5 篇）
- **来源**：[ARCH §8]
- **内容**：ADR-001 至 ADR-005（不重构理由 / FeedbackCenter actor 选择 / 状态机手写 / Registry 运行时 / SF Symbols 过渡）
- **产出**：`docs/adr/ADR-00X-*.md` × 5
- **工时**：2 d
- **依赖**：无
- **审批人**：CTO / 资深架构师

### W0-TL-02 ✦ SwiftLint 自定义规则配置（5 条护栏）
- **来源**：[ARCH §6.1]
- **内容**：禁止 `Image(systemName:)` 字面量 / 禁止 `Color(hex:)` 字面量（Token 文件除外）/ 禁止裸 `accessibilityLabel` 字面量 / `.animation(.easeInOut(duration:))` 必须用 Token / TerminalView ≤ 300 行 CI 检查
- **产出**：`.swiftlint.yml` 更新 + 5 条 custom rules + CI 集成
- **工时**：1.5 d
- **依赖**：无

### W0-PM-01 ✦ Sprint 计划会 + 6 周需求冻结
- **内容**：与产品确认本期不接新需求；冻结 W1-W6 范围；通报相关方
- **工时**：0.5 d

**W0 周末交付（关键里程碑）**：
- ✅ Figma 200+ 节点 4 类 Token + 6 套组件规格 完成（DSN 全部任务）
- ✅ 5 篇 ADR 评审通过
- ✅ SwiftLint 5 条 custom rules 生效
- ✅ W1 启动 Go/No-Go 决策会

---

## W1：横切层 Foundation 一期（2026-06-15 → 06-21）

> **W1 主旨**：a11y + Feedback 两个横切层落地，不触及业务功能，为 W2-W6 提供基础设施。

### W1-iOS-A-01 ✦ 创建 `Shared/Accessibility/` 模块
- **来源**：[UE-P0#1 / ARCH §1.1]
- **内容**：`AccessibilityModifiers.swift` + `AccessibilityCatalog.swift` + 3 个语义 modifier（A11yConnectionStatus / A11yTabSelection / A11yChatMessage）
- **产出**：模块代码 + 单测 ≥ 80% 覆盖率
- **工时**：3 d
- **依赖**：无

### W1-iOS-A-02 ✦ 创建 `Shared/Feedback/` 模块
- **来源**：[UE-P1#8 / ARCH §1.2 / UI §3.1]
- **内容**：`FeedbackCenter`（@MainActor actor）+ `FeedbackEvent` + `FeedbackAction` + `ToastHost` + `InlineRecoveryBanner` + `SystemNotificationBridge`
- **产出**：模块代码 + 4 类 level 的 SwiftUI Preview
- **工时**：4 d
- **依赖**：W0-DSN-03（Figma 规格）

### W1-iOS-B-01 ✦ Token 实现端落地（与 Figma 对齐）
- **来源**：[UI §1.2 / §4.4]
- **内容**：在 `Shared/Utilities/` 新增 `DesignTokens+Semantic.swift` / `DesignTokens+Elevation.swift` / `DesignTokens+Gradient.swift` / 扩展 `Typography+Mono`
- **产出**：4 个新 token 文件 + SwiftUI Preview 验证亮/深
- **工时**：2 d
- **依赖**：W0-DSN-01

### W1-iOS-B-02 ✦ 硬编码颜色 Token 化（迁移 6 处）
- **来源**：[UE-P2#19 / UI §4.3]
- **内容**：TunnelModels.swift 3 处 + WelcomeScreenView 3 处 → 迁入新 Semantic / Gradient token
- **产出**：6 处替换 + SwiftLint 规则生效后无回归
- **工时**：1 d
- **依赖**：W1-iOS-B-01

### W1-iOS-B-03 ✦ Elevation 阴影统一改造（10+ 组件）
- **来源**：[UI §4.4]
- **内容**：扫描 Card / Toast / Popover / Sheet 等组件的阴影硬编码，统一改用 `e1-e4` token
- **产出**：组件改造 + 深色模式内描边 fallback
- **工时**：2 d
- **依赖**：W1-iOS-B-01

### W1-DSN-01 ✦ 5 套状态机视觉矩阵设计
- **来源**：[ARCH §1.3 / UI §3.3]
- **内容**：TerminalConnection 10 态 / TabLifecycle 7 态 / OnboardingFlow / AIConsent / SettingsDirty
- **产出**：Figma `States/*` 5 个 Frame
- **工时**：4 d
- **依赖**：W0 全部 Token

### W1-DSN-02 ✦ Spotlight Overlay 视觉规格
- **来源**：[UI §3.3.3]
- **内容**：挖洞高亮 + 旁置 tooltip 卡片
- **产出**：Figma `Patterns / Spotlight`
- **工时**：1 d
- **依赖**：W0-DSN-04

### W1-TL-01 ✦ Feedback 与现有 Alert 共存迁移规则文档
- **来源**：[ARCH §7 风险点]
- **内容**：定义哪些场景必须迁移 Feedback、哪些保留 Alert、过渡期对照表
- **产出**：`docs/feedback-migration-guide.md`
- **工时**：1 d

**W1 周末交付**：
- ✅ Accessibility 模块可用（含 5 个语义 modifier）
- ✅ FeedbackCenter 可在终端任一处触发 4 level toast + banner
- ✅ 4 套新 Token 实现端可用，硬编码颜色清零
- ✅ Elevation 阴影系统全量改造
- ✅ Demo：连接失败 → 红色 banner 含 "重新输入密码" 按钮（虽未接 handler，视觉先到位）

---

## W2：横切层 Foundation 二期（2026-06-22 → 06-28）

> **W2 主旨**：UI 状态机落地 + 全量 a11y 标签补齐。

### W2-iOS-A-01 ✦ 状态机基础设施 `UIState` 协议
- **来源**：[ARCH §1.3]
- **内容**：`UIState` protocol + `StateMachine<S>` 通用包装 + SwiftUI 桥接
- **产出**：核心协议 + 单测
- **工时**：1.5 d

### W2-iOS-A-02 ✦ TerminalConnectionState 10 态实现
- **来源**：[ARCH §1.3 / UI §3.3.1]
- **内容**：完整状态枚举 + Event reduce + UI 派生（displayBadge / availableActions / allowsTabClose）
- **产出**：状态机 + 状态机单测覆盖 ≥ 85%
- **工时**：3 d
- **依赖**：W2-iOS-A-01, W1-DSN-01

### W2-iOS-A-03 ✦ TabLifecycleState 7 态实现
- **来源**：[UE-P0#3 / ARCH §1.3 / UI §3.3.2]
- **内容**：状态机 + "活动检测"规则（5s 输出） + 关闭守卫
- **产出**：状态机 + 配合 TabBar 接入
- **工时**：2 d
- **依赖**：W2-iOS-A-01

### W2-iOS-A-04 ✦ AIConsentState / SettingsDirtyState / OnboardingFlowState
- **来源**：[ARCH §1.3]
- **内容**：3 个轻量级状态机
- **产出**：3 个状态机 + 单测
- **工时**：1.5 d
- **依赖**：W2-iOS-A-01

### W2-iOS-B-01 ✦ a11y 标签全量补齐（30+ 处）
- **来源**：[UE-P0#1 / ARCH §1.1 / UI §4.2]
- **内容**：SessionRow 状态点 / TabBar 选中 / AI 气泡 / SFTP 文件行 / 工具栏按钮 / CPU sparkline / Tmux 列表 / 录制状态 ... 全部接入 AccessibilityCatalog
- **产出**：所有交互元素具备 .accessibilityLabel + .accessibilityHint + 必要 traits
- **工时**：3 d
- **依赖**：W1-iOS-A-01

### W2-iOS-B-02 ✦ 状态点颜色 + 形状双通道改造
- **来源**：[UI §4.2]
- **内容**：SessionRow 状态点改为颜色+形状双通道（connected 实心圆/connecting 旋转圆环/disconnected 空心圆/error 含 `!` 实心圆）
- **产出**：StatusDotView 组件升级
- **工时**：1 d
- **依赖**：W1-iOS-B-01

### W2-iOS-B-03 ✦ Focus Ring 系统建立 + 全组件 retrofit
- **来源**：[UE-P1 a11y / UI §4.5]
- **内容**：`.focusedRing()` modifier + 所有按钮/输入框/列表行接入
- **产出**：统一 Focus Ring 视觉，键盘 Tab 流畅
- **工时**：2 d
- **依赖**：W1-iOS-B-01

### W2-iOS-B-04 ✦ Tab 误关闭保护接入
- **来源**：[UE-P0#3]
- **内容**：TabBar 接入 TabLifecycleState，关闭活动 Tab 时弹 Confirm + ⌘⇧T 恢复实现
- **产出**：关键场景行为符合预期
- **工时**：1.5 d
- **依赖**：W2-iOS-A-03, W1-iOS-A-02

### W2-DSN-01 ✦ 工具栏重组 final 视觉
- **来源**：[UE-P0#5 / UI §4.1]
- **内容**：AI 渐变按钮 + 「工具▾」菜单 + 智能折叠规则
- **产出**：Figma `Patterns / Toolbar Reorganized`
- **工时**：2 d
- **依赖**：W0-DSN-02

### W2-DSN-02 ✦ AI 同意 Inline 引导视觉
- **来源**：[UE-P1#12 / UI §3.3]
- **内容**：AI 面板内嵌协议 + 示例 prompt 预览 + 「同意并开始」CTA
- **产出**：Figma `Patterns / AI Consent Inline`
- **工时**：1 d
- **依赖**：W1-DSN-01

### W2-QA-01 ✦ a11y 自动化测试基线建立
- **来源**：[ARCH §6.2]
- **内容**：XCUITest 模板 + 关键视图 a11y 快照 baseline
- **产出**：5+ 测试用例
- **工时**：2 d
- **依赖**：W2-iOS-B-01 中段（部分完成可启动）

**W2 周末交付**：
- ✅ 5 套 UI 状态机完成且单测覆盖 ≥ 80%
- ✅ 全量 a11y 标签补齐，VoiceOver 走查无空标签
- ✅ Focus Ring 跨组件统一
- ✅ Tab 误关闭保护生效，⌘⇧T 恢复可用
- ✅ **里程碑评审 #1**：UE P0#1 + P0#3 关闭

---

## W3：Discoverability + 图标迁移（2026-06-29 → 07-05）

> **W3 主旨**：让 AI 浮出水面、让所有能力可被搜索。

### W3-iOS-A-01 ✦ CapabilityRegistry 核心
- **来源**：[ARCH §1.4]
- **内容**：`Capability` 数据结构 + 全局注册中心 + 各 Feature 自注册（AI / SFTP / Tmux / Tunnel / Script / Recording / Log / QuickCommand）
- **产出**：注册中心 + 8 个能力注册
- **工时**：2.5 d
- **依赖**：W2-iOS-A-04（OnboardingFlowState）

### W3-iOS-A-02 ✦ Command Palette `⌘K` 实现
- **来源**：[UE-P1 #13 思路同源 / ARCH §1.4 / UI §3.2]
- **内容**：⌘K 触发 + 浮窗 + 搜索引擎（含 fuzzy match）+ 5 态 UI（默认 / 聚焦 / 搜索 / 无结果 / AI 增强）
- **产出**：完整 ⌘K 功能，覆盖所有 Capability
- **工时**：4 d
- **依赖**：W3-iOS-A-01, W0-DSN-04

### W3-iOS-A-03 ✦ OnboardingDirector + Spotlight 实现
- **来源**：[UE-P1 #6 #7 / ARCH §1.4]
- **内容**：触发规则引擎（首次连接成功 / 7 天未用 AI）+ Spotlight Overlay 渲染 + 首次启动示例会话注入
- **产出**：OnboardingDirector 模块 + WelcomeScreen 接入新建会话流程
- **工时**：3 d
- **依赖**：W3-iOS-A-01, W1-DSN-02

### W3-iOS-B-01 ✦ AppIcon enum 实现 + 全量替换
- **来源**：[UE-P1#17 / ARCH §3.1]
- **内容**：`AppIcon` enum + 自动 a11yLabel 绑定 + 全 codebase 替换 Unicode 图标
- **产出**：所有图标走 AppIcon，SwiftLint 规则 0 警告
- **工时**：3 d
- **依赖**：W0-DSN-02

### W3-iOS-B-02 ✦ 工具栏重组实施
- **来源**：[UE-P0#5 / UI §4.1]
- **内容**：左右分组重组 + AI 渐变按钮 + 「工具▾」菜单 + 智能折叠
- **产出**：ContentViewToolbar 改造完成
- **工时**：2 d
- **依赖**：W3-iOS-B-01, W2-DSN-01

### W3-iOS-B-03 ✦ AI 同意 Inline 引导
- **来源**：[UE-P1#12]
- **内容**：AIConsentState 接入 + 面板内嵌协议 + 示例 prompt 预览
- **产出**：首次打开 AI 面板转化率视觉到位
- **工时**：1.5 d
- **依赖**：W2-iOS-A-04, W2-DSN-02

### W3-DSN-01 ✦ PreflightProgressView 视觉规格
- **来源**：[UE-P0#2 / ARCH §3.2 / UI §3.6]
- **内容**：4 阶段 × 5 状态 + 失败 inline 展开 + 阶段图标动效
- **产出**：Figma `Components / Preflight`
- **工时**：2 d

### W3-DSN-02 ✦ PasteGuard + SettingsSearch 视觉规格
- **来源**：[UE-P1 #14 #18]
- **内容**：粘贴警告 overlay + 设置搜索高亮跳转
- **产出**：2 套视觉规格
- **工时**：1.5 d

### W3-QA-01 ✦ Command Palette E2E 测试
- **内容**：⌘K 打开 / 搜索 / 选择 / 关闭 + 无结果引导 AI 链路
- **产出**：5+ E2E 用例
- **工时**：1.5 d
- **依赖**：W3-iOS-A-02 完成

**W3 周末交付**：
- ✅ ⌘K 命令面板可用，覆盖 8+ 能力
- ✅ 工具栏重组完成，AI 卖点视觉浮出
- ✅ 全部 Unicode 图标迁移到 SF Symbols
- ✅ 首次启动→新建会话→AI 引导链路通畅
- ✅ **里程碑评审 #2**：UE P0#5 + P1 #6 #7 #12 #17 关闭

---

## W4：基础设施补强 + Preflight（2026-07-06 → 07-12）

> **W4 主旨**：让"测试连接"和"骨架屏"双双上线，体验质感跃升。

### W4-iOS-A-01 ✦ LoadingPresentation 模块
- **来源**：[UE-P1#15 / ARCH §1.5 / UI §3.4]
- **内容**：`LoadingContainer` + 5 种 presentation + Skeleton 3 套蓝图 + 1400ms shimmer + 80ms 错峰
- **产出**：模块 + 5+ 业务接入点（侧边栏 / SFTP / AI / 设置 / 录制列表）
- **工时**：3 d
- **依赖**：W0-DSN-05

### W4-iOS-A-02 ✦ Settings Search Index 系统
- **来源**：[UE-P1#13 / ARCH §3.3]
- **内容**：`SettingItem` 数据结构 + 各 Settings Tab 自注册 + SettingsSearchBar 实现 + 高亮跳转
- **产出**：设置面板顶部搜索框可用，覆盖 50+ 设置项
- **工时**：2.5 d
- **依赖**：W3-DSN-02

### W4-iOS-A-03 ✦ Settings 未保存提醒
- **来源**：[UE-P1#14]
- **内容**：接入 SettingsDirtyState，切换 Tab / 关闭面板时弹 Confirm
- **产出**：设置编辑安全保护
- **工时**：1 d
- **依赖**：W2-iOS-A-04

### W4-iOS-B-01 ✦ ConnectionPreflightService 实现
- **来源**：[UE-P0#2 / ARCH §3.2]
- **内容**：分阶段 preflight（DNS / TCP / SSH 握手 / 认证）+ 独立 Socket + 5s 超时强制释放 + 复用 ConnectionErrorAnalysis
- **产出**：Service 层 + 单测覆盖 4 阶段失败场景
- **工时**：3 d
- **依赖**：无（独立模块）

### W4-iOS-B-02 ✦ SessionFormSheet 接入「测试连接」按钮
- **来源**：[UE-P0#2 / UI §3.6]
- **内容**：表单底部新增次按钮 + PreflightProgressView 嵌入 + 失败建议接 Feedback Action
- **产出**：新建会话表单完成度提升
- **工时**：2 d
- **依赖**：W4-iOS-B-01, W3-DSN-01

### W4-iOS-B-03 ✦ 密码"按住显示明文"
- **来源**：[UE-P1#10]
- **内容**：SecureField 右侧 👁 图标，按住显示，松开隐藏
- **产出**：FormComponents 扩展
- **工时**：0.5 d

### W4-iOS-B-04 ✦ 分组下拉内联「新建分组」
- **来源**：[UE-P1#11]
- **内容**：Dropdown 增加 "+ 新建分组..." 选项，触发 Inline Sheet
- **产出**：表单不需关闭即可创建分组
- **工时**：1 d

### W4-iOS-B-05 ✦ 网络断开 macOS 通知接入
- **来源**：[UE-P1#9 / ARCH §1.2]
- **内容**：TerminalConnectionState 切换至 `.disconnected(.networkLost)` 时触发 SystemNotificationBridge
- **产出**：用户切换 App 时不漏断连
- **工时**：1 d
- **依赖**：W1-iOS-A-02, W2-iOS-A-02

### W4-DSN-01 ✦ ConnectionStateOverlay 大号重连按钮规格
- **来源**：[UE-P1#16 / UI §3.3.1]
- **内容**：中央"重新连接"主按钮 + 5s 自动重连倒计时进度环 + ConnectionErrorView 接入
- **产出**：Figma `Components / Connection Overlay`
- **工时**：1.5 d

### W4-QA-01 ✦ Preflight + Feedback 集成测试
- **内容**：4 阶段成功 / 4 阶段失败 / 失败建议按钮 / 网络通知触发
- **产出**：10+ 集成用例
- **工时**：2 d
- **依赖**：W4-iOS-B-02

**W4 周末交付**：
- ✅ 骨架屏覆盖 5+ 场景
- ✅ 设置面板顶部搜索可用 + 未保存提醒
- ✅ 新建会话「测试连接」按钮上线
- ✅ 网络断开 macOS 通知
- ✅ **里程碑评审 #3**：UE P0#2 + P1 #9 #10 #11 #13 #14 #15 关闭

---

## W5：TerminalView 拆分 + Overlay 落地（2026-07-13 → 07-19）

> **W5 主旨**：1200 行 TerminalView 拆解为 5 个 ≤300 行组件，重连/粘贴 overlay 上线。

### W5-iOS-B-01 ✦ TerminalView 拆分 Phase 1：Layout 抽离
- **来源**：[UE 技术债 / ARCH §2]
- **内容**：抽出 `TerminalPanelLayout.swift` + `SFTPSlidePanel.swift` + `TerminalThemeApplier.swift`
- **产出**：TerminalView 从 1200 → ~700 行
- **工时**：2.5 d
- **风险**：SwiftTerm Representable 边界需谨慎，PR 单独提交

### W5-iOS-B-02 ✦ TerminalView 拆分 Phase 2：Overlay 抽离
- **来源**：[ARCH §2]
- **内容**：抽出 `SearchOverlay.swift` + `ConnectionStateOverlay.swift` + `PasteGuardOverlay.swift` + `TerminalConnectionState` 文件分离
- **产出**：TerminalView 从 700 → ≤ 300 行，SwiftLint 行数检查通过
- **工时**：3 d
- **依赖**：W5-iOS-B-01

### W5-iOS-B-03 ✦ ConnectionStateOverlay 业务接入
- **来源**：[UE-P1#16 / UI §3.3.1]
- **内容**：绑定 TerminalConnectionState.availableActions，渲染重连按钮 + 倒计时 + 错误诊断
- **产出**：终端断开后中央显示"重新连接"，5s 自动重试
- **工时**：1.5 d
- **依赖**：W5-iOS-B-02, W4-DSN-01

### W5-iOS-B-04 ✦ PasteGuardOverlay 实现
- **来源**：[UE-P1#18]
- **内容**：检测多行粘贴 / 危险命令（rm -rf 等）/ 大量内容（>1000 行）→ 弹出确认
- **产出**：粘贴保护机制
- **工时**：1.5 d
- **依赖**：W5-iOS-B-02

### W5-iOS-A-01 ✦ BUG-002 双击事件冒泡修复
- **来源**：[UE-P0#4]
- **内容**：调查 SessionListView 双击触发父级问题 + 用 `.onTapGesture(count: 2)` 显式拦截
- **产出**：双击行为符合预期
- **工时**：1.5 d
- **风险**：可能需要 SwiftUI gesture composer 调整

### W5-iOS-A-02 ✦ Feedback Action handler 全量接入
- **来源**：[UE-P1#8]
- **内容**：retry / editCredentials / acceptHostKey / testNetwork / openSettings 5 类 handler 接入业务方法
- **产出**：错误 banner 上的按钮全部可用
- **工时**：2 d
- **依赖**：W4-iOS-B-01, W2-iOS-A-02

### W5-DSN-01 ✦ a11y 视觉走查文档
- **来源**：[UE-P0#1 收尾]
- **内容**：用 VoiceOver 实际操作 5 个主流程，记录视觉与朗读不一致的位置
- **产出**：`a11y-audit-report.md`
- **工时**：2 d

### W5-QA-01 ✦ 拆分后回归测试
- **内容**：终端连接 / 断开 / 重连 / 搜索 / 粘贴 / 复制 / 字体切换 全链路回归
- **产出**：回归报告
- **工时**：3 d
- **依赖**：W5-iOS-B-02

**W5 周末交付**：
- ✅ TerminalView.swift ≤ 300 行
- ✅ 终端重连按钮 + 粘贴保护上线
- ✅ Feedback Action handler 全量接入
- ✅ BUG-002 修复
- ✅ a11y 视觉走查报告产出
- ✅ **里程碑评审 #4**：UE P0#4 + P1 #8 #16 #18 关闭

---

## W6：完善 + 全量回归（2026-07-20 → 07-26）

> **W6 主旨**：清理 P2 长尾、全量回归、上线准备。

### W6-iOS-A-01 ✦ Onboarding 流程接入新建会话
- **来源**：[UE-P1#6]
- **内容**：Welcome 第 3 步 "立即新建一个 SSH 会话" → 直接打开 SessionFormSheet
- **产出**：首次启动转化路径流畅
- **工时**：1 d
- **依赖**：W3-iOS-A-03

### W6-iOS-A-02 ✦ 示例会话/演示模式
- **来源**：[UE-P1#7]
- **内容**：首次启动检测无会话时，注入一个 `localhost:22` 示例 + 说明气泡
- **产出**：新用户首屏不空
- **工时**：1 d

### W6-iOS-A-03 ✦ Welcome "再次显示" 设置入口
- **来源**：[UE-P2#27]
- **内容**：「通用」Settings Tab 加 "再次显示欢迎引导" 按钮
- **产出**：用户可回看引导
- **工时**：0.5 d

### W6-iOS-B-01 ✦ 隧道运行中状态栏指示器
- **来源**：[UE-P2#21]
- **内容**：状态栏新增"🔗 N 条隧道运行中"，点击直达 TunnelManagerView
- **产出**：隧道状态可见
- **工时**：1 d

### W6-iOS-B-02 ✦ Tooltip 加 ⓘ 解释（术语）
- **来源**：[UE-P2#23]
- **内容**：Keychain / SSH Agent / Passphrase 等术语加 hover Tooltip
- **产出**：新手友好度提升
- **工时**：1 d

### W6-iOS-B-03 ✦ 动画时长 Token 化清理
- **来源**：[UE-P2#20 / UI §1.1 已澄清部分]
- **内容**：清理少量硬编码 `.easeInOut(duration: 0.3/0.5)` → 用 medium / slow
- **产出**：动画 Token 化 100%
- **工时**：0.5 d

### W6-iOS-B-04 ✦ 快捷命令 vs 脚本说明
- **来源**：[UE-P2#22]
- **内容**：两个面板顶部加对比说明 + "命令 → 脚本"互转按钮
- **产出**：用户区分清晰
- **工时**：1 d

### W6-DSN-01 ✦ Figma Code Connect 全量映射
- **来源**：[UI §7.2]
- **内容**：本期新增 6 套组件全部建立 Code Connect → Swift 映射
- **产出**：代码与 Figma 双向同步
- **工时**：2 d

### W6-QA-01 ✦ 全量 a11y 真机回归
- **来源**：[ARCH §6.3]
- **内容**：VoiceOver 走查 W2 a11y-audit-report 中的所有路径
- **产出**：a11y 验收报告
- **工时**：2 d
- **依赖**：W5-DSN-01

### W6-QA-02 ✦ P0/P1 端到端验收
- **内容**：UE Review 中 5 个 P0 + 13 个 P1 逐条验证
- **产出**：验收报告 + 未完成项 backlog
- **工时**：2 d

### W6-TL-01 ✦ 后续维护手册
- **内容**：5 横切层的接入指南 + 5 个 ADR review 修订 + 后续 P2 backlog 编排
- **产出**：`docs/architecture-handbook.md`
- **工时**：1.5 d

### W6-PM-01 ✦ 发版评审 + 回顾
- **内容**：召集利益相关方评审本期成果 + 项目回顾
- **工时**：0.5 d

**W6 周末交付**：
- ✅ 所有 P0 (5/5) 关闭
- ✅ 所有 P1 (13/13) 关闭
- ✅ P2 关闭 6/9（剩余 3 项：英文文案 review / 大数据性能基准 / Dynamic Type 进入下期）
- ✅ a11y 全量验收通过
- ✅ Figma ↔ 代码 Code Connect 同步
- ✅ **里程碑评审 #5（终审）**：版本可发布

---

## 3. 任务依赖关系图（关键依赖）

```
W0-DSN-01 (Token) ──┬─→ W1-iOS-B-01 (Token 实现) ──┬─→ W1-iOS-B-02 (颜色迁移)
                    │                              └─→ W1-iOS-B-03 (Elevation)
                    │
                    ├─→ W0-DSN-03 (Feedback 规格) ─→ W1-iOS-A-02 (FeedbackCenter)
                    │                                       │
                    └─→ W0-DSN-04 (Palette 规格) ──────────┤
                                                            ↓
W0-DSN-02 (AppIcon) ─→ W3-iOS-B-01 (AppIcon impl) ─→ W3-iOS-B-02 (工具栏重组)
                                                            ↑
W2-DSN-01 (工具栏视觉) ─────────────────────────────────────┘

W1-iOS-A-01 (a11y) ─→ W2-iOS-B-01 (a11y 补齐) ─→ W5-DSN-01 (走查) ─→ W6-QA-01 (回归)

W2-iOS-A-01 (UIState) ─┬─→ W2-iOS-A-02 (Terminal State)
                       ├─→ W2-iOS-A-03 (Tab State) ─→ W2-iOS-B-04 (误关保护)
                       └─→ W2-iOS-A-04 (其他 3 State)
                                  ↓
                                  ├─→ W3-iOS-B-03 (AI Consent)
                                  ├─→ W4-iOS-A-03 (Settings Dirty)
                                  └─→ W3-iOS-A-03 (Onboarding)

W4-iOS-B-01 (Preflight Svc) ─→ W4-iOS-B-02 (表单接入)

W5-iOS-B-01 (Layout 拆分) ─→ W5-iOS-B-02 (Overlay 拆分) ─┬─→ W5-iOS-B-03 (Reconnect)
                                                         └─→ W5-iOS-B-04 (PasteGuard)
```

---

## 4. 里程碑与质量门

| # | 时间 | 里程碑 | 通过标准 |
|---|---|---|---|
| M0 | W0 末 | 设计 + 架构基线就绪 | 4 套 Token Figma 定稿 + 6 套组件规格 + 5 篇 ADR 评审通过 + SwiftLint 规则上线 |
| M1 | W2 末 | Foundation 横切就位 | 5 套状态机单测 ≥ 80% + a11y 标签 0 空 + Feedback demo 可触发 |
| M2 | W3 末 | Discoverability 上线 | ⌘K 覆盖 8+ 能力 + 工具栏重组 demo + Unicode 图标 0 残留 |
| M3 | W4 末 | 「测试连接」上线 | Preflight 4 阶段覆盖率 ≥ 90% + 骨架屏 5+ 场景 + Settings Search 50+ 项 |
| M4 | W5 末 | TerminalView 拆分完成 | TerminalView.swift ≤ 300 行 + 拆分回归 0 P0/P1 bug |
| M5 | W6 末 | 终验 | UE P0 (5/5) + P1 (13/13) 全关闭 + a11y 真机验收通过 |

---

## 5. 资源分配视图（人力负载）

### 5.1 iOS 工程师 A（Foundation）：~30 工作日

| 周 | 主要任务 | 工时 |
|---|---|---|
| W1 | Accessibility + Feedback 模块 | 5d (W1-iOS-A-01/02 共 7d，部分进入 W2) |
| W2 | UIState + 5 套状态机 | 5d |
| W3 | CapabilityRegistry + Palette + Director | 5d (Palette 4d 跨周) |
| W4 | LoadingPresentation + SettingsSearch | 5d |
| W5 | BUG-002 + Feedback handler | 3.5d (轻周) |
| W6 | Onboarding 收尾 + 示例会话 | 2.5d (轻周) |

### 5.2 iOS 工程师 B（Feature/Refactor）：~30 工作日

| 周 | 主要任务 | 工时 |
|---|---|---|
| W1 | Token 实现 + 颜色迁移 + Elevation | 5d |
| W2 | a11y 补齐 + 状态点 + Focus Ring + Tab 保护 | 5d (W2-iOS-B-01 3d 跨周) |
| W3 | AppIcon + 工具栏重组 + AI 同意 | 5d |
| W4 | Preflight + 表单 + 密码 + 通知 + 分组 | 5d |
| W5 | TerminalView 拆分 + Overlay | 5d (W5-iOS-B-01/02 5.5d) |
| W6 | 隧道指示 + Tooltip + 动画清理 + 命令脚本 | 3.5d |

### 5.3 UI 设计师：~25 工作日

| 周 | 主要任务 | 工时 |
|---|---|---|
| W0 | 4 套 Token + AppIcon + Feedback + Palette + Skeleton | 9d（高峰）|
| W1 | 状态机视觉矩阵 + Spotlight | 5d |
| W2 | 工具栏重组 + AI 同意 | 3d |
| W3 | Preflight + PasteGuard + SettingsSearch | 3.5d |
| W4 | ConnectionOverlay | 1.5d |
| W5 | a11y 视觉走查 | 2d |
| W6 | Code Connect 映射 | 2d |

### 5.4 QA：~12 工作日（W2 加入）

| 周 | 主要任务 | 工时 |
|---|---|---|
| W2 | a11y 自动化基线 | 2d |
| W3 | Palette E2E | 1.5d |
| W4 | Preflight 集成 | 2d |
| W5 | 拆分回归 | 3d |
| W6 | a11y 真机回归 + 终验 | 4d |

### 5.5 Tech Lead：~8 工作日

W0 ADR 2d + SwiftLint 1.5d + Feedback 迁移规则 1d + 每周架构 sync 0.5d × 6 = 3d + W6 架构手册 1.5d。

---

## 6. 风险缓冲与应急方案

### 6.1 已识别风险（来自架构方案 §7）

| 风险 | 触发条件 | 应急动作 |
|---|---|---|
| TerminalView 拆分回归 | W5 末出现 P0/P1 回归 | 回滚至 W4 版本，拆分推迟到 W7+；W5/W6 P2 任务前置 |
| Feedback 与 Alert 共存混乱 | W2 出现双重通知 | 立即下发 W1-TL-01 迁移规则；冻结新 Alert 使用 |
| ⌘K 快捷键冲突 | W3 测试发现冲突 | 提供自定义快捷键设置（W6 任务前置）|
| Preflight 资源冲突 | W4 测试发现连接占用 | 强制 Preflight 用独立 Socket + 5s 超时（已在设计中） |
| W0 Figma 高峰 9d 设计师超载 | W0 末规格未完成 | 优先级排序：Token + Feedback + Palette + AppIcon 必须 W0 完成；Skeleton + State 矩阵可推迟到 W1 并行 |

### 6.2 时间缓冲

- 每周预留 0.5 d 作 buffer（处理 PR review、突发 bug）
- W6 末预留 1 d 整体缓冲
- 关键路径任务（W0 设计、W3 ⌘K、W5 拆分）延期 > 2 d 立即升级

### 6.3 范围降级方案（若进度落后）

按降级优先级排序（先砍最低优先级）：

1. **L1（首选降级）**：W6 P2 任务（隧道指示 / Tooltip / 命令脚本说明）推迟到下期
2. **L2**：W4 SettingsSearch 推迟（保留未保存提醒）
3. **L3**：W3 OnboardingDirector 简化（只做示例会话，不做触发规则引擎）
4. **L4（红线，需评审）**：W2 a11y 补齐降级为关键路径 10 处

---

## 7. 沟通节奏

| 频次 | 形式 | 参与人 | 时长 |
|---|---|---|---|
| 每日 | Daily Standup（异步飞书） | 全体 | 0 |
| 每周一 | Sprint 计划 + 上周回顾 | 全体 | 1h |
| 每周三 | 架构 sync（横切层接入情况） | iOS + TL + DSN | 30min |
| 每周五 | 里程碑评审（仅 M0-M5 周） | 全体 + PM + 利益相关方 | 1h |
| 临时 | 阻塞协调（关键路径阻塞） | 相关方 | 按需 |

---

## 8. 度量与可观测

### 8.1 过程度量

- 每周 PR 数 / Review 平均时长
- SwiftLint 5 条 custom rules 触发次数（应趋零）
- TerminalView.swift 行数趋势（W5 末降至 ≤ 300）
- 状态机单测覆盖率（每个状态机 ≥ 80%）

### 8.2 结果度量

- UE Review 27 条问题闭环率（目标 W6 末：P0 100%、P1 100%、P2 67%）
- a11y 标签覆盖率（目标 W2 末：100%）
- 硬编码颜色/动画时长扫描结果（目标 W3 末：0）
- Figma 与代码 Component 对齐率（目标 W6 末：本期新增 100%）

### 8.3 用户度量（上线后追踪，非本期范围）

- AI 助手 7 日激活率
- 「测试连接」按钮使用率
- ⌘K 命令面板月活
- VoiceOver 用户留存

---

## 9. 整合视角的关键洞察

### 9.1 三份文档的一致性验证

整合过程中确认：

- ✅ UE Review 的 27 条问题 → 100% 在架构方案中找到对应模块
- ✅ 架构方案的 5 横切层 → 100% 在 UI 自评中有视觉规格
- ✅ UI 自评的 6 套组件 → 100% 在排期中找到实现任务

**结论**：三份文档**自洽**，可以同时执行而不会出现"设计了没人做"或"做了没设计"的尴尬。

### 9.2 W0 是本计划的真正胜负手

- 若 W0 设计稿不就位 → W1 编码无视觉规格 → 后续 6 周全部受影响
- 若 W0 ADR 未通过 → 架构选型可能在 W3 反复 → 关键路径塌方
- **建议**：W0 当作"压力测试"管理，每日同步进度，必要时增援设计资源

### 9.3 W2 末是验证型里程碑

- W1-W2 完成横切层后，**Demo 一个"连接失败 → 红 banner → 重输密码 → 成功"完整闭环**
- 若 Demo 不顺，说明 Feedback / State Machine / Accessibility 抽象不正确，应回头修订
- 这是**架构方案的小范围试金石**，比 W6 才发现问题代价小 10 倍

### 9.4 不在本计划范围（明示）

| 项目 | 原因 |
|---|---|
| 多窗口架构 | 架构 §9 长期视图，超期 |
| 大规模性能基准测试 | 独立项目，下季度 |
| 英文文案母语者 review | 外协并行 |
| Dynamic Type 支持 | 优先级低于本期 P0/P1 |
| 第三方插件生态 | 架构 §9 长期视图 |
| 协作功能（CRDT） | 远期路线 |

---

## 10. 一页式总结

> **6 周 + W0 准备周**，**3 人月工程 + 1 人月设计 + 0.6 人月 QA**，闭环 **5 个 P0 + 13 个 P1**，建立 **5 个横切层 + 3 个基础设施 + 1 次拆分**，沉淀 **3 套新 Token + 6 套新组件 + 5 篇 ADR**，最终交付一份在 **可用性、可达性、可发现性、可恢复性** 四个维度都成熟的 macOS 原生应用。

---

**计划负责人**：PM（A） + Tech Lead（C）
**关联文档**：
- `ShellMate_UE_Review_2026-06-07.md`
- `ShellMate_架构优化方案_2026-06-07.md`
- `ShellMate_UI_Self_Review_2026-06-07.md`
- `开发进度.md`（既有 17 周 WBS，本期作为其中 7 周块嵌入）
**版本**：v1.0
**评审历史**：待 W0 启动会评审签字
