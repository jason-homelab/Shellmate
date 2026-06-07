# ShellMate UI 设计自评报告

> **Review 类型**：UI 设计自我评审 + 新架构组件设计提案
> **撰写视角**：资深 UI 设计师（自检 + 主动产出方案）
> **撰写日期**：2026-06-07
> **基线文档**：
>   - `ShellMate_UE_Review_2026-06-07.md`（UE 评审 — 问题来源）
>   - `ShellMate_架构优化方案_2026-06-07.md`（架构方案 — 新组件来源）
>   - Figma Desktop `OBPyCWFtlCx5OEIXwrckZm`（权威设计源）
>   - `DesignTokens+*.swift`（实现端 Token 真相）

---

## 0. 自评前的态度声明

作为 UI 设计师，**我要回答两个问题，而不只是一个**：

1. **现有 UI 哪里需要优化？**（被动 — 回应 UE Review）
2. **架构方案催生的新组件，UI 该怎么设计？**（主动 — 设计师该输出的成果）

UE 工程师指出体验问题、架构师给出模块边界，但**Feedback Banner 长什么样、Command Palette 的视觉语言是什么、骨架屏的节奏、Preflight 阶段卡的微动效**——这些必须由 UI 设计师定义，否则方案落地时会变形。

本文档既是 self-review，也是面向 W1-W6 实施的**视觉规格交付前置稿**。

---

## 1. 现状盘点：Design Token 真相核对

在评估优化之前，先核对底盘。**部分 UE Review 中提到的"缺失"实际已存在**，必须澄清以免重复造轮子。

### 1.1 已具备的 Token（盘点结果）

| Token 维度 | 状态 | 说明 |
|---|---|---|
| 表面 4 层（window/panel/card/overlay/input） | ✅ 完整 | 自适应亮/深，深色为冷蓝白色调（Void 系） |
| 玻璃覆层（5 级 + 悬停/按压） | ✅ 完整 | glassUltraLight → glassPressStrong |
| 玻璃边框（顶/侧/底/Accent） | ✅ 完整 | 模拟光折射方向感 |
| 品牌色 + AI 色 + 脚本色 | ✅ 完整 | #077aff / #818cf8 / #fb923c |
| 文字 5 级（primary/secondary/tertiary/disabled/subtle） | ✅ 完整 | 含 textSubtle 介于 secondary 与 tertiary 之间 |
| 状态色（connected/connecting/disconnected/error） | ✅ 完整 | 推测覆盖 4 态 |
| 间距 nano→xxl（10 级） | ✅ 完整 | 2pt 起步，足够精细 |
| 圆角 XXSmall→Large（5 级） | ✅ 完整 | 4/6/8/12/16pt |
| 动画分级 fast/standard/medium/slow + spring/glass/hover | ✅ 完整 | **UE Review 误判为缺失，实际 7 档完备** |

### 1.2 真实的 Token 缺口

| 缺口 | 影响范围 | 严重度 |
|---|---|---|
| **Semantic Feedback 色板**（info/success/warn/error 各自的 fg/bg/border 三件套） | Feedback 中枢、Toast、Banner、Preflight 阶段、Highlight | 🔴 高 |
| **Skeleton 骨架色**（base/shimmer 双层） | LoadingPresentation 所有场景 | 🔴 高 |
| **Focus Ring** 系统（focusOuter/focusInner/focusOffset） | a11y 全量 + ⌘K 命令面板 | 🟡 中 |
| **Tunnel 规则语义色**（local/remote/socks） | 隧道列表，当前硬编码 hex | 🟢 低 |
| **Welcome 渐变色**（radial 3 色） | Welcome 屏，当前硬编码 hex | 🟢 低 |
| **Capability Category 色**（connection/ai/productivity/files） | 新 CommandPalette + 重组后工具栏分类 | 🟡 中 |
| **Z-Index Token**（base/overlay/modal/toast/palette） | 多层覆盖物层级混乱风险 | 🟡 中 |
| **Elevation 阴影分级**（e1/e2/e3/e4） | 卡片/弹窗/Toast/Palette 区分层级 | 🟡 中 |

**判断**：底盘 75 分起步，要落地架构方案，需要补 8 类新 Token。这不是 UI 的"修补"，而是**设计系统的下一阶段升级**。

---

## 2. UI 自评总分

| 维度 | 评分 | 较 UE Review | 说明 |
|---|---|---|---|
| 色彩系统 | 4.5 / 5 | 持平 | Void 暗色系成熟，但 Semantic 层缺失 |
| 字体节奏 | 4.0 / 5 | -0.5 | 等宽体配置到位，但**Typography Token 仅 Display/Title 等级，缺数据展示场景的 mono variant 分级** |
| 间距韵律 | 5.0 / 5 | 持平 | nano→xxl 极细致 |
| 圆角语言 | 4.5 / 5 | 持平 | 5 级分明 |
| 阴影/层级 | 3.5 / 5 | -1.0 | **新发现：阴影散落在组件中硬编码，无 Elevation token** |
| 动效手感 | 4.5 / 5 | +1.0 | **UE 误判，实际已分 7 档**，少量硬编码可清理 |
| 图标体系 | 2.5 / 5 | 持平 | Unicode 文本图标必须迁移 |
| 状态可视化 | 3.0 / 5 | -0.5 | **新发现：状态机引入后，每个状态都需视觉规格**，当前仅"已连接/未连接"二态有标准 |
| 信息密度 | 4.0 / 5 | 持平 | 状态栏密度好，工具栏过载 |
| 品牌表达力 | 3.5 / 5 | -0.5 | AI 是核心卖点但视觉无强调 |
| 亮/深模式对等 | 4.5 / 5 | 持平 | 自适应基本到位 |

**UI 整体得分：4.0 / 5**

**结论**：UI 底盘扎实，但**架构方案要求的 5 个新模块都伴随未定义的视觉规格**。本期 UI 工作的重点不是修旧账，而是**为新架构定义视觉语言**，否则架构方案落地时各 PR 各定一套，回到散乱状态。

---

## 3. 新架构组件 × UI 设计规格（核心产出）

以下 6 套规格直接对应架构方案中的横切层。每套包含：**视觉描述 + 关键尺寸 + 色彩 Token + 动效 + 状态矩阵 + Figma 节点提案**。

---

### 3.1 Feedback Banner & Toast 视觉系统

**来源**：架构 §1.2 Feedback 中枢

#### 3.1.1 设计意图

让用户**在 ≤1 秒内**判断：发生了什么（level）、影响多大（severity）、我能做什么（action）。当前 Alert 弹窗式反馈过于"打断"，需要新的 inline 形态。

#### 3.1.2 四个 Level × 两种形态

```
形态 A：Toast（短时）        形态 B：Banner（持续到操作）
┌──────────────────────┐    ┌──────────────────────────────────┐
│ ⓘ 已复制公钥到剪贴板  │    │ ⚠ 认证失败：密码不正确              │
└──────────────────────┘    │   [ 重新输入密码 ] [ 测试网络 ] ✕ │
   ↑ 自动消失 3s             └──────────────────────────────────┘
                                ↑ 持续显示直到用户操作
```

#### 3.1.3 Level 色彩规格（新增 Semantic Token）

| Level | 图标 | 前景 | 背景（亮） | 背景（深） | 边框 |
|---|---|---|---|---|---|
| info | ⓘ `info.circle.fill` | `#077aff` | `#077aff` @ 8% | `#077aff` @ 14% | `#077aff` @ 22% |
| success | ✓ `checkmark.circle.fill` | `#10b981` | `#10b981` @ 8% | `#10b981` @ 14% | `#10b981` @ 22% |
| warn | ⚠ `exclamationmark.triangle.fill` | `#f59e0b` | `#f59e0b` @ 10% | `#f59e0b` @ 16% | `#f59e0b` @ 26% |
| error | ⨯ `xmark.octagon.fill` | `#ef4444` | `#ef4444` @ 10% | `#ef4444` @ 16% | `#ef4444` @ 28% |

**注意**：success 不复用 `accentSecondary`（#34d399），因为后者是"已连接"语义；feedback success 用 `#10b981`（emerald-500）以拉开语义距离。

#### 3.1.4 关键尺寸

| 元素 | 值 | 备注 |
|---|---|---|
| Toast 高度 | 44pt | 单行 |
| Toast 内边距 | 12pt / 16pt | 垂直/水平 |
| Toast 圆角 | 10pt | 介于 Small(8) 和 Medium(12) 之间 — **新增 `cornerRadiusToast = 10`** |
| Toast 最大宽度 | 360pt | 防止长文案撑爆 |
| Toast 阴影 | `e3`：0/8/24/rgba(0,0,0,0.18) | **新 Elevation Token** |
| Banner 高度 | 自适应 56pt 起步 | 含按钮组 |
| Banner 边框 | 1pt + level 色 @ 22% | |
| Banner 左侧 indicator 条 | 4pt 宽 × 全高 | level 实色，强化语义 |

#### 3.1.5 动效

- **Toast 入场**：`spring (0.4, 0.85)` + 从右上滑入 16pt + opacity 0→1 — 280ms
- **Toast 出场**：opacity 1→0 + scale 1→0.96 — 200ms `easeOut`
- **Banner 入场**：高度 0→target + opacity 0→1 — 320ms `glass`
- **Action 按钮 hover**：背景透明度 +6% — 120ms `hover`

#### 3.1.6 多 Toast 堆叠规则

- 最多同时显示 3 个
- 间距 8pt（spacing.xxs）
- 第 4 条来时：最旧的 dismiss（不替换为 "..."）
- 同 level 不合并（不模仿 macOS Notification 合并），保证可读性

#### 3.1.7 Figma 交付节点

- 新建 Frame `Feedback / Toast / Info Success Warn Error`
- 新建 Frame `Feedback / Banner / With Actions × 4 Levels`
- 新建 Variant Component `FeedbackBanner` props: `level / hasActions / actionCount`

---

### 3.2 Command Palette（⌘K）视觉设计

**来源**：架构 §1.4 Discoverability

#### 3.2.1 设计意图

成为 ShellMate 的**"超能力中枢"**——区别于普通设置搜索的视觉记忆点。竞品参考：Raycast、Linear、Arc Cmd Bar。但**不抄袭**，要做出 ShellMate 自己的气质（更克制、更专业、更接近 macOS 系统体验）。

#### 3.2.2 视觉骨架

```
                  ┌─────────────────────────────────────────┐
                  │  🔍  在 ShellMate 中搜索...    ⌘K  ✕     │  ← 56pt
                  ├─────────────────────────────────────────┤
                  │  会话                                    │  ← 28pt section header
                  │  ⚡ 连接 prod-web-01           ⌘↩       │  ← 36pt row
                  │  📁 在 prod-web-01 上打开 SFTP  ⌘⇧S      │
                  │                                          │
                  │  操作                                    │
                  │  ✦ 询问 AI: "如何查看磁盘空间"  ⌘I       │  ← AI 行特殊渲染
                  │  📜 运行脚本: 清理日志            ⌘R       │
                  │                                          │
                  │  设置                                    │
                  │  ⚙ 终端字体大小                          │
                  └─────────────────────────────────────────┘
                  ↑ 580pt 宽 × 自适应高（最高 480pt）
                  ↑ 浮在窗口正中偏上（屏幕上方 1/3）
```

#### 3.2.3 关键设计决策

| 决策点 | 选择 | 理由 |
|---|---|---|
| 位置 | 窗口居中偏上（top inset 80pt） | 不遮挡操作目标；视线自然落点 |
| 宽度 | 580pt 固定 | 既能放下两栏（icon + title + shortcut）又不致占满 |
| 背景 | `.regularMaterial`（NSVisualEffectView） | macOS 原生材质，区分于普通窗口 |
| 圆角 | 14pt — **新 `cornerRadiusFloating`** | 介于 Medium(12) 和 Large(16)，浮窗专用 |
| 阴影 | `e4`：0/24/64/rgba(0,0,0,0.32) | 最大层级阴影，与背景明确分离 |
| 边框 | 0.5pt + glassBorderTop | 不抢戏，仅做边缘清晰化 |
| 输入框 | 无边框，仅靠图标 + 占位文字 | macOS Spotlight 风格 |
| 行高 | 36pt | 紧凑但不局促 |
| 行选中态 | 整行背景 `glassSelected` + 左侧 3pt 蓝条 | 键盘导航的强视觉锚点 |

#### 3.2.4 AI 行的视觉强化（落地 UE Review P0#5 卖点突出）

普通行：单色 SF Symbol + 文本
AI 行：`accentAI` 渐变 icon + 输入内容的 quoted 灰字 + 右上角 `Powered by Claude` 微标

```
✦  询问 AI: "如何查看磁盘空间"                    ⌘I  ✦
   ↑ 渐变 icon                                          ↑ AI 标识
```

#### 3.2.5 入场动效

- 触发：⌘K
- 背景遮罩：0→0.2 黑色 — 200ms `easeOut`
- 浮窗：scale 0.94→1 + y 偏移 -12pt→0 + opacity 0→1 — 280ms `spring(0.35, 0.78)`
- 输入框自动聚焦 + Caret 闪烁

#### 3.2.6 空态 / 加载态 / 无结果态

| 态 | 视觉 |
|---|---|
| 空（刚打开） | 显示「最近使用」5 项 + 「推荐操作」3 项 |
| 输入中加载（异步搜索时） | 输入框右侧微 spinner（不阻塞键入） |
| 无结果 | 中央 `sparkles` icon + "试试用自然语言问 AI" + AI 行入口 |

**这是产品的高光时刻**：让无结果不是"挫败"而是"引导至 AI"。

#### 3.2.7 Figma 交付节点

- 新建 Frame `Discoverability / Command Palette` × 5 态（默认/聚焦/搜索中/无结果/AI 增强）
- 单独 Component `Palette Row` props: `category / hasShortcut / isAI / isSelected`

---

### 3.3 State Machine 衍生的状态可视化矩阵

**来源**：架构 §1.3 — 5 个状态机引入后，每个 state 都需要视觉规格。

#### 3.3.1 TerminalConnectionState 视觉矩阵

| 状态 | 状态点颜色 | 中央 Overlay | 工具栏连接按钮 | StatusBar 文案 |
|---|---|---|---|---|
| `idle` | 灰 `textTertiary` | — | 蓝色「连接」实心 | "未连接" |
| `connecting(.dns)` | 黄脉冲（1s 一次） | 中央 4 阶段 stepper | 灰色「连接中」+ spinner | "DNS 解析中..." |
| `connecting(.tcp)` | 黄脉冲 | stepper 进 2/4 | 同上 | "TCP 握手中..." |
| `connecting(.handshake)` | 黄脉冲 | stepper 进 3/4 | 同上 | "SSH 握手中..." |
| `connecting(.auth)` | 黄脉冲 | stepper 进 4/4 | 同上 | "认证中..." |
| `connected` | 绿 `statusConnected` + 微微 glow | — | 红色「断开」轮廓 | "已连接 · since 10:32" |
| `reconnecting(attempt: 2)` | 橙脉冲（更急促，0.6s） | 大号「重新连接 (2/5)」按钮 + 倒计时进度环 | 灰色「重连中」+ spinner | "重连尝试 2/5" |
| `disconnected(.userInitiated)` | 灰 | 中央「重新连接」次按钮 | 蓝色「连接」 | "已断开" |
| `disconnected(.networkLost)` | 红 | 中央红色 banner + "重连"主按钮 + "检查网络"次 | 蓝色「连接」 | "网络断开" |
| `failed(.auth)` | 红 | 中央 ConnectionErrorView + actions | 蓝色「连接」 | "认证失败" |

**关键设计**：脉冲动画的频率传递紧迫感
- 常规 connecting：1.0s 周期，opacity 0.4↔1.0
- reconnecting：0.6s 周期，opacity 0.3↔1.0
- failed：不闪烁，静态红，避免视觉骚扰

#### 3.3.2 TabLifecycleState 视觉矩阵

| 状态 | Tab 显示 | 关闭行为 |
|---|---|---|
| `active(.idle)` | 标准选中态 | 直接关闭 |
| `active(.runningCommand)` | 标准 + 标题左侧 `dot.fill` 蓝点（标识活动） | 关闭时 confirm dialog |
| `active(.error)` | 标准 + 标题左侧红点 | 关闭时 confirm |
| `background(.idle)` | 灰底 | 直接关闭 |
| `background(.unreadOutput)` | 灰底 + 标题右侧蓝色 badge 数字 | 直接关闭 |
| `closing` | opacity 1→0.4 + scale 1→0.92 | — |
| `closed(.recoverable)` | 不显示，但留在「最近关闭」⌘⇧T 列表 | — |

**"活动检测"视觉规则**：终端最近 5 秒有输出 → `runningCommand`，呼应 UE Review P0#3。

#### 3.3.3 OnboardingFlowState 衍生的 Spotlight 系统

新引入 `SpotlightOverlay`：在用户进入特定 state 时，对目标 UI 做"挖洞"高亮 + 旁置 tooltip。

```
全屏半透明黑遮罩 ┐
                ▼
┌────────────────────────────────────┐
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░░┌─────────┐░░░░░░░░░░░  │  ← 工具栏 AI 按钮被"挖出"
│  ░░░░░░░░░░│  ✦ AI   │░░░░░░░░░░░  │
│  ░░░░░░░░░░└─────────┘░░░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░  ┌──────────────┐ │
│  ░░░░░░░░░░░░░░░░  │ 试试 AI 助手 │ │
│  ░░░░░░░░░░░░░░░░  │ 让 AI 帮你写 │ │
│  ░░░░░░░░░░░░░░░░  │ 命令         │ │
│  ░░░░░░░░░░░░░░░░  │ [稍后]   [试一下]│ │
│  ░░░░░░░░░░░░░░░░  └──────────────┘ │
└────────────────────────────────────┘
```

**规格**：
- 遮罩：黑色 @ 50%
- 高亮孔：跟随目标元素 bounds + 8pt padding + 14pt 圆角 + 内发光 `accentAI` @ 60%
- Tooltip 卡片：宽 280pt × 自适应 + `e3` 阴影 + 14pt 圆角

#### 3.3.4 Figma 交付节点

- Frame `States / Terminal Connection` × 10 态
- Frame `States / Tab Lifecycle` × 7 态
- Component `Spotlight Overlay`

---

### 3.4 LoadingPresentation 骨架屏体系

**来源**：架构 §1.5

#### 3.4.1 骨架色 Token（新增）

```swift
skeletonBase:    亮 #e8e8ed   /   深 white @ 5%
skeletonShimmer: 亮 #f3f3f7   /   深 white @ 10%
skeletonBorder:  亮 #00000000 /   深 white @ 3%
```

#### 3.4.2 骨架节奏规则（防止"心跳大舞会"）

| 规则 | 值 |
|---|---|
| Shimmer 周期 | 1400ms |
| Shimmer 缓动 | `easeInOut` |
| Shimmer 方向 | 从左上 → 右下，30° 角 |
| Shimmer 宽度 | 占行宽 40% |
| 多行错峰 | 每行 delay +80ms（连续 5 行后归零） |
| 圆角 | 沿用骨架对象的圆角（文字行 4pt、卡片 12pt） |

**反例**：所有行同步 shimmer → 视觉噪声。错峰后产生"波浪"感，符合人眼对加载的预期。

#### 3.4.3 三类骨架蓝图

```
A. SkeletonSidebar（侧边栏 - 8 行）
┌─────────────────┐
│ ▓▓▓▓▓▓▓▓ ▓▓▓    │  ← 行高 36pt
│  ▓▓▓▓▓▓▓▓▓     │     icon 16pt + 文字行 + 状态点
│  ▓▓▓▓▓▓▓▓      │
│ ▓▓▓▓ ▓▓▓▓      │  ← 分组标题
│  ▓▓▓▓▓▓▓▓▓     │
│  ▓▓▓▓▓▓▓▓      │
│  ▓▓▓▓▓▓        │
│  ▓▓▓▓▓▓▓       │
└─────────────────┘

B. SkeletonFileRow（SFTP 文件 - 灵活行数）
│ ▓ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓     ▓▓▓▓ ▓▓▓▓▓▓▓ │
   ↑    ↑                ↑    ↑
  icon  name           size   date

C. SkeletonCard（AI 消息卡 - 自适应高度）
┌───────────────────────┐
│ ▓ ▓▓▓▓▓                │  ← 头部
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓        │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     │
└───────────────────────┘
```

---

### 3.5 AppIcon 系统 — SF Symbols 迁移视觉规范

**来源**：架构 §3.1

#### 3.5.1 选符策略

UE Review 提到 Unicode `⏻ ✦ </> ⇅ ⊡` 的字宽不一致问题。SF Symbols 迁移不是简单替换，**每个图标的语义、权重、视觉重量都要重新选择**。

| 旧 Unicode | 旧含义 | 新 SF Symbol | 视觉重量 | 备选 |
|---|---|---|---|---|
| `⏻` | 连接 | `power.circle.fill` (connected) / `power` (idle) | medium | `bolt.fill` |
| `✦` | AI 助手 | `sparkles` | regular | `wand.and.stars` |
| `</>` | 脚本 | `chevron.left.forwardslash.chevron.right` | regular | `terminal` |
| `⇅` | SFTP 文件 | `folder.fill.badge.gearshape` | medium | `arrow.up.arrow.down` |
| `⊡` | 分屏 | `square.split.2x1` / `square.split.2x2` | regular | — |
| - | Tmux | `rectangle.3.group` | regular | `square.grid.3x3` |
| - | 隧道 | `arrow.left.arrow.right.circle` | regular | `network` |
| - | 日志 | `text.alignleft` | regular | `doc.text` |
| - | 录制 | `record.circle` | regular | `dot.circle` |
| - | 命令面板 | `command` | regular | `magnifyingglass` |

#### 3.5.2 视觉权重规则

- **工具栏图标**：`.regular` × 17pt
- **侧边栏图标**：`.medium` × 14pt
- **状态/装饰图标**：`.semibold` × 13pt
- **Onboarding/营销图标**：`.bold` × 24pt + 渐变填充

#### 3.5.3 渐变填充规范（限定 AI / 高亮场景）

```swift
AI 渐变填充（仅 sparkles / wand 等 AI 语义）：
  从 #818cf8 → #5856d6，角度 135°
  应用方式：foregroundStyle(LinearGradient(...))

避免：常规工具栏图标不渲染渐变，保持克制
```

---

### 3.6 PreflightProgressView 阶段化进度视觉

**来源**：架构 §3.2 ConnectionPreflightService

#### 3.6.1 设计意图

把"测试连接"的 4 个隐形步骤显形化，**让等待变成可读的进度叙事**。

#### 3.6.2 视觉骨架

```
┌──────────────────────────────────────┐
│  测试连接...                          │
│                                      │
│  ✓ 解析主机名               18ms     │  ← success：绿勾 + 实时耗时
│  ✓ 建立 TCP 连接           242ms     │
│  ◐ SSH 协议握手...                   │  ← in-progress：旋转 0.75 圆环
│  ○ 用户身份认证                      │  ← pending：灰空圆
│                                      │
│  ──────────                          │  ← 整体进度条
└──────────────────────────────────────┘
```

#### 3.6.3 阶段图标规格

| 状态 | 图标 | 色 | 动效 |
|---|---|---|---|
| pending | 空圆 `circle` | `textTertiary` | — |
| in-progress | 0.75 圆环 `circle.dotted` | `accentPrimary` | rotation 360° / 1.4s linear |
| success | `checkmark.circle.fill` | `statusConnected` | scale 0.6→1 spring + opacity |
| failed | `xmark.circle.fill` | feedback error 红 | scale 0.6→1 spring + 横向 shake 4pt |
| skipped | `minus.circle` | `textDisabled` | — |

#### 3.6.4 失败后的行动指引

某阶段失败时，**该行展开 inline 建议卡片**：

```
✓ 解析主机名               18ms
✗ 建立 TCP 连接           5000ms   超时
  ┌────────────────────────────────────┐
  │ 可能原因：                          │
  │  • 主机不在线或防火墙阻止           │
  │  • 端口号错误（当前 2222）          │
  │                                    │
  │  [ 检查防火墙 ] [ 切换 22 端口 ]    │
  └────────────────────────────────────┘
○ SSH 协议握手             （已跳过）
○ 用户身份认证             （已跳过）
```

**这正是 §3.1 Feedback Banner 的复用**——证明设计语言的一致性。

---

## 4. 现有视觉债的系统化清理

不是"逐条修"，而是**借这次架构升级一次性还清**。

### 4.1 工具栏图标墙的视觉破局（呼应 UE-P0#5）

#### 4.1.1 现状画像

```
[⏻ 连接] [✦ AI] [</> 脚本] [⇅ 文件] [⊡ 分屏] [日志] [命令] [隧道]
   ↑ 8 个等权重 pill 按钮，AI 这个核心卖点没有任何强调
```

#### 4.1.2 重组方案（视觉版）

```
┌─ 左：会话操作（2 个，恒常需要）─────┐  ┌─ 中：会话徽章 ─┐  ┌─ 右：能力入口（克制）──┐
│  [⏻ 连接]                          │  │ · prod-web-01 · │  │  [✦ AI]   [⊞ 工具 ▾]   │
│                                    │  └─────────────────┘  │   ↑核心    ↑收纳菜单     │
└────────────────────────────────────┘                       └─────────────────────────┘
```

**关键视觉决策**：

1. **AI 按钮独立 + 渐变填充**：
   - 背景：`LinearGradient(accentAI → accentIndigo, 135°)` @ 12% 常态、@ 22% hover
   - 边框：`accentAI` @ 30%
   - icon：`sparkles` 渐变实色
   - 文字 "AI"：`accentAI` 实色
   - 唯一一个"非中性"按钮，自然吸引视线

2. **「工具 ▾」收纳菜单**：
   - SFTP / Tmux / 隧道 / 脚本 / 日志 / 命令 / 录制 → 收入下拉
   - 下拉菜单按 Category 分区：📁 文件 / 🔀 网络 / 📜 自动化 / 📊 监控
   - 顶部加 "搜索操作... ⌘K" 横条，无缝引向 Command Palette

3. **会话徽章保留**（已实现）但增加微动效：连接时左侧的"·"变为脉冲点

#### 4.1.3 替代方案：智能折叠工具栏

窗口宽 > 1200pt 时显示完整工具栏（不含「工具▾」，展开常用 4 项）；窗口 ≤ 1200pt 时自动折叠至「工具▾」。

---

### 4.2 SessionRow 连接状态点的视觉升级

UE Review 仅指出 a11y 缺失，但**视觉本身也有改进空间**。

#### 4.2.1 当前问题

- 4 态都用圆点 + 颜色区分，色弱用户辨识困难
- 颜色已传递语义但**形状未承担信息**

#### 4.2.2 改进：颜色 + 形状双通道

| 状态 | 颜色 | 形状 |
|---|---|---|
| connected | 绿 | 实心圆 + 外发光 4pt |
| connecting | 黄 | 旋转 0.75 圆环 |
| disconnected | 灰 | 空心圆 |
| error | 红 | 实心圆 + 内含 `!` |

满足 WCAG 关于"不仅以颜色传递信息"的要求，同时无障碍标签 + 形状 + 颜色三通道确认。

---

### 4.3 硬编码颜色的 Token 化清单

| 当前位置 | hex | 新 Token 命名 | 归属层 |
|---|---|---|---|
| TunnelModels.swift `#7AB4F5` | local forward | `semantic.tunnelLocal` | Semantic |
| TunnelModels.swift `#F5C842` | remote forward | `semantic.tunnelRemote` | Semantic |
| TunnelModels.swift `#C88AF0` | dynamic socks | `semantic.tunnelSocks` | Semantic |
| WelcomeScreenView `#4299fd` | welcome 渐变 | `gradient.welcomeStart` | Gradient |
| WelcomeScreenView `#7eb7fb` | welcome 渐变 | `gradient.welcomeMid` | Gradient |
| WelcomeScreenView `#bad6f9` | welcome 渐变 | `gradient.welcomeEnd` | Gradient |

借此机会**建立 `DesignTokens.Semantic` 与 `DesignTokens.Gradient` 两个新命名空间**，与现有 `Colors` 平级，语义层和原子层分离。

---

### 4.4 阴影/Elevation 体系建立（新工作）

发现新问题：当前阴影散落在组件文件中（Card / Toast / Popover 各定一套），需统一。

#### 4.4.1 5 级 Elevation Token

| 等级 | 用途 | 规格 |
|---|---|---|
| `e0` | flat 元素（侧边栏行） | none |
| `e1` | 卡片、Pill 按钮 | y:1, blur:2, color: rgba(0,0,0,0.06) |
| `e2` | 浮起按钮、状态栏分隔 | y:2, blur:6, color: rgba(0,0,0,0.10) |
| `e3` | Toast、Tooltip、Popover | y:8, blur:24, color: rgba(0,0,0,0.18) |
| `e4` | Modal、Sheet、Command Palette | y:24, blur:64, color: rgba(0,0,0,0.32) |

亮模式按上表，深模式需要**反向"内透"**（用浅色边框模拟，因为深色背景上传统阴影不可见）：
- 深模式 e1-e2：上边缘 1pt `white @ 6%` 内描边
- 深模式 e3-e4：传统阴影 × 1.5 倍 blur + 上边缘 1pt `white @ 10%` 内描边

---

### 4.5 Focus Ring 系统（a11y 联动）

**当前**：依赖 SwiftUI 默认 focus ring，跨组件视觉不一致。

**新规范**：

```
focusRingColor:  accentPrimary
focusRingWidth:  2.5pt
focusRingOffset: 2pt
focusRingRadius: 沿用元素圆角 + 2pt
```

通过 `.focusedRing()` modifier 统一施加：
- 键盘 Tab 导航到的按钮、输入框、列表行
- 不应用于鼠标点击（macOS 标准行为）

---

## 5. Typography Token 补强

发现新缺口：当前 Typography 仅按"角色"分级（Title / Body / Caption），缺**数据展示场景的等宽体节奏**。

新增 `DesignTokens.Typography.mono` 子命名空间：

```swift
mono.code:     SFMono 13 / 1.5 行高 / -0.1 字距   // 终端 / 代码块
mono.dataXS:   SFMono 11 / 1.4 / 0                // StatusBar 数字
mono.dataSM:   SFMono 12 / 1.5 / 0                // 表格数据
mono.label:    SFMono 11 SemiBold / 1.4 / +0.5    // SFTP 字节单位
```

**为什么**：状态栏的 CPU 数字、SFTP 的字节单位、Preflight 的耗时显示，全部需要等宽对齐，**避免数字跳动**。

---

## 6. 多窗口 / 多 Tab 协作下的视觉一致性预案

虽然多窗口在架构 §9 长期视图中，但 UI 设计应当**为未来留出语言**：

- **窗口标题区** 引入"会话徽章" → 多窗口时一眼区分
- **TabBar** 在多窗口未来需要加 dragHandle 视觉
- **Toast** 需要明确"窗口域"还是"全局域"：约定**全局事件用 macOS Notification**、窗口内事件用 in-window toast

提前确立视觉边界，避免日后视觉补丁。

---

## 7. Figma 端工作分解（W1 开工前完成）

设计师在 W0（启动前）需要在 Figma `OBPyCWFtlCx5OEIXwrckZm` 完成以下交付，**否则架构方案落地时会"视觉真空"**。

### 7.1 新增 Figma Pages

| Page | 内容 | 交付节点估算 |
|---|---|---|
| `Tokens / Semantic` | feedback 4 色板、tunnel 3 色、status 4 态、focus ring | 24 |
| `Tokens / Elevation` | e0-e4 × 亮/深 × 内描边规范 | 12 |
| `Tokens / Typography Mono` | mono.code/dataXS/dataSM/label | 8 |
| `Tokens / Gradient` | welcome 3 色、AI 渐变、accent 渐变 | 6 |
| `Components / Feedback` | Toast × 4 level / Banner × 4 level / 含 actions 变体 | 16 |
| `Components / Command Palette` | 默认/聚焦/搜索/无结果/AI 增强 × 行变体 | 20 |
| `Components / Skeleton` | sidebar / fileRow / aiCard 三套 + shimmer 帧 | 12 |
| `Components / Preflight` | 4 阶段 × 5 状态 + 失败展开 | 18 |
| `Components / AppIcon` | 全量 SF Symbol 映射表 + 渲染示例 | 24 |
| `States / Terminal Connection` | 10 态视觉矩阵 | 20 |
| `States / Tab Lifecycle` | 7 态 + 关闭确认 | 12 |
| `Patterns / Spotlight` | onboarding 高亮模式 | 8 |
| `Patterns / Toolbar Reorganized` | 重组前后对比 + 工具菜单 | 10 |

**总计约 200 个 Figma 节点 / 设计师约 8-10 工作日**

### 7.2 Code Connect 映射

借此机会，把上述新 Component 全部建立 Code Connect 映射，让代码与 Figma 双向同步——这是 ShellMate 文档 `2.4` 所追求的"1:1 对齐"在新增组件上的延续。

---

## 8. 设计交付物清单（端到端）

### 8.1 W0（架构开工前 1 周）

- [ ] Semantic / Elevation / Gradient / Typography mono 四套 Token 在 Figma 定稿
- [ ] AppIcon 全量映射表 + Swift 端 `AppIcon` enum 设计稿
- [ ] FeedbackBanner + Toast 4 level 视觉规格
- [ ] Command Palette 5 态主屏 + 行组件

### 8.2 W1-W2（Foundation 阶段同步）

- [ ] Skeleton 三套蓝图 + shimmer 帧动画规格
- [ ] Focus Ring 全组件 retrofit 设计
- [ ] State Machine 5 套状态视觉矩阵（Terminal 10 / Tab 7 / Onboarding / AIConsent / Settings dirty）

### 8.3 W3（Discoverability 阶段同步）

- [ ] 工具栏重组 final（含 AI 渐变规格、Tools 菜单分类）
- [ ] Spotlight Overlay 规格
- [ ] AI 同意 inline 引导视觉

### 8.4 W4（Polish 同步）

- [ ] PreflightProgressView 4 阶段 × 5 态 + 失败展开
- [ ] PasteGuard Overlay 规格
- [ ] SettingsSearch 高亮跳转视觉

### 8.5 W5-W6（Refactor + Integration）

- [ ] ConnectionStateOverlay 大号重连按钮规格 + 倒计时环
- [ ] 全量 a11y 视觉走查（Focus Ring、状态点形状、对比度）

---

## 9. 风险与权衡（设计师视角）

| 风险 | 说明 | 缓解 |
|---|---|---|
| 同时引入 6 套新视觉组件，设计师成为瓶颈 | W0 集中 8-10 天 Figma 输出压力大 | 优先级排序：Feedback + Palette + Skeleton 必须 W0 前完成；State 矩阵可 W1 并行；Preflight 可推迟至 W3 末 |
| 新 Semantic 色板与现有 accent* 命名混淆 | 开发可能错用 | 明确分层文档：accent = 品牌色，semantic = 语义色；Lint 规则限制 accentPrimary 用于品牌触点之外 |
| Toast 与系统 Notification 边界不清 | 双重通知打扰用户 | 设计师与架构师共同制定路由表：错误/警告优先 in-window，长时间后台事件才走系统 |
| SF Symbols 在 macOS 13 部分符号不可用 | UE Review 已提及 | 选型时强制使用 SF Symbols ≤ 4.0 的符号；建立 fallback 表 |
| 渐变 AI 按钮过度营销感 | 与 ShellMate 专业气质冲突 | 渐变限定 12-22% 透明度施加在背景；icon/文字保持单色，避免"花哨" |
| 多窗口未来视觉变化 | 现在做完未来要重做 | 本期视觉约定"单窗口内"语义，所有 Toast/Banner 不假设全局 |

---

## 10. 设计师视角的总评与立场

### 10.1 现状

ShellMate 当前 UI 是**专业、克制、对齐 Figma 的好底盘**，得分 4.0/5。但**只能支撑现有功能**，不足以承载架构方案带来的新模块。

### 10.2 本期 UI 的重点

不在"修补现有界面"，而在 **"为新架构定义视觉语言"**：

- **5 个横切层 → 6 套视觉规格** （Feedback / Palette / Skeleton / State Matrix / AppIcon / Preflight）
- **3 套新 Token 命名空间** （Semantic / Elevation / Gradient）
- **1 次工具栏重组**（让 AI 卖点视觉浮出）
- **1 次 a11y 视觉走查**（Focus Ring + 状态点形状双通道）

### 10.3 不做什么（克制）

- **不重做** SessionForm / Settings / TerminalView 主视觉——它们已对齐 Figma
- **不引入** 新品牌色或字体——克制是 ShellMate 的气质
- **不追** Raycast / Linear 风——做"专业工程师工具"，不做"消费级花活"

### 10.4 一句话立场

> 这次 UI 工作不是"美化"，是为 ShellMate 的下一阶段**建语言**。
> 6 周后，新功能开发不再需要设计师从 0 思考视觉，**调用 Token 与 Component 即可达到 Figma 对齐水准**——这才是设计系统真正成熟的标志。

---

**UI 设计师**：Claude（代理资深 UI 设计师视角）
**关联文档**：
- `ShellMate_UE_Review_2026-06-07.md`
- `ShellMate_架构优化方案_2026-06-07.md`
- Figma Desktop `OBPyCWFtlCx5OEIXwrckZm`
- `DesignTokens+*.swift`（代码端真相）
**版本**：v1.0
