# ShellMate — Figma 集成设计系统规则文档 v3.0

> **本文档供 AI 助手（Claude MCP）在 Figma → SwiftUI 转换工作流中使用。**
> **所有设计决策必须严格遵循本文档规范。**
> **更新日期：2026-03-30（基于 Figma Make Shell 原型全面重构）**

---

## 1. 设计语言概述

ShellMate v3.0 采用 **macOS Native** 设计语言，以 Apple 标准系统 UI 为基础，融合选择性玻璃拟态（仅用于浮层）。

**三大视觉支柱：**

```
① macOS Native（原生优先）
   ├── 颜色严格使用 Apple HIG 语义色
   ├── 工具栏/侧边栏材质：系统 vibrancy（#f5f5f7 半透明）
   └── 控件跟随 controlAccentColor（#007AFF）

② 选择性玻璃感（Selective Glass）
   ├── 仅弹窗/浮层：bg-white/90~95 + backdrop-blur-xl
   ├── AI 面板、SFTP 面板：bg-white/90 + backdrop-blur-xl
   └── 普通卡片不使用玻璃，使用 surfaceCard

③ 精致交互（Refined Interaction）
   ├── 所有按钮 hover/press：duration-200 过渡
   ├── 面板展开/折叠：duration-300 ease-in-out
   └── 状态切换动画适中，避免过度动效
```

---

## 2. 颜色令牌（DesignTokens.Colors）

### 2.1 强制使用的令牌（禁止硬编码替换）

| 令牌 | Light | Dark | 用途 |
|------|-------|------|------|
| `accentPrimary` | `#007AFF` | `#007AFF` | 主按钮、选中态、链接 |
| `accentIndigo` | `#5856D6` | `#5856D6` | 内存图标、AI 渐变 |
| `accentSecondary` | `#38BDF8` | `#38BDF8` | 次级高亮、渐变辅色 |
| `statusConnected` | `#34C759` | `#34D399` | 已连接状态 |
| `statusConnecting` | `#FF9500` | `#FBBF24` | 连接中/警告 |
| `statusError` | `#FF3B30` | `#FB7185` | 错误状态 |
| `statusOffline` | `#8E8E93` | `#475569` | 离线状态 |
| `textPrimary` | `#1D1D1F` | `#EDF0FF` | 主要文字 |
| `textSecondary` | `#86868B` | `#8892AA` | 次要文字 |
| `textTertiary` | `#AEAEB2` | `#525D78` | 说明/占位文字 |
| `surfaceWindow` | `#F5F5F7` | `#07090F` | 应用背景 |
| `surfacePanel` | `#F5F5F7 95%` | `#0C1018` | 侧边栏/工具栏 |
| `surfaceCard` | `#FFFFFF 95%` | `#101520` | 弹窗/卡片 |
| `surfaceInput` | `#FFFFFF 80%` | `#0A0E1A` | 输入框背景 |
| `borderPrimary` | `rgba(0,0,0,0.10)` | `rgba(255,255,255,0.10)` | 通用边框 |
| `glassBorderSide` | `rgba(0,0,0,0.07)` | `rgba(255,255,255,0.07)` | 侧面玻璃边框 |
| `glassMedium` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.09)` | 玻璃覆层 |

### 2.2 交互状态颜色（直接量，不抽取令牌）

```
Light Mode hover:    rgba(0,0,0,0.05)   = bg-black/5
Light Mode press:    rgba(0,0,0,0.10)   = bg-black/10
Light Mode selected: #007AFF            = bg-accentPrimary（带文字反白）

Dark Mode hover:     rgba(255,255,255,0.08)   = glassHover
Dark Mode selected:  accentPrimary @ 14%      = glassSelected
```

### 2.3 禁用的颜色值（v2.0 遗留，已废弃）

```
❌ #2C7EF8  → ✅ accentPrimary (#007AFF)
❌ #60A5FA  → ✅ accentSecondary (#38BDF8)
❌ #F5A623  → ✅ statusConnecting
❌ 任何 Color(hex:"#xxxxxx") 直接写法（DesignTokens.swift 中的 primitive 除外）
```

---

## 3. 间距令牌（DesignTokens.Spacing）

```swift
xxxs = 2pt   // 最小间隔
xxs  = 4pt   // 超小
xs   = 6pt   // 紧凑（工具栏按钮间）
sm   = 8pt   // 小（卡片内行间距）
md   = 12pt  // ★ 标准（区块内边距）
lg   = 16pt  // ★ 大（内容区域）
xl   = 20pt  // 超大（面板 padding）
xxl  = 24pt  // 模块分组
xxxl = 32pt  // 顶级分区
```

**禁止写法：** `.padding(14)` `.padding(.horizontal, 16)` 等任何数字字面量
**正确写法：** `.padding(DesignTokens.Spacing.lg)` `.padding(.horizontal, DesignTokens.Spacing.md)`

---

## 4. 尺寸令牌（DesignTokens.Sizes）

```swift
cornerRadiusXSmall = 4pt   // 标签/徽章
cornerRadiusSmall  = 8pt   // 按钮、输入框
cornerRadiusMedium = 10pt  // 卡片容器
cornerRadiusLarge  = 12pt  // 面板
cornerRadiusXLarge = 16pt  // 弹窗内大模块

statusBarHeight    = 32pt  // 状态栏高度（h-8）
toolbarHeight      = 48pt  // 工具栏高度（h-12）
tabBarHeight       = 40pt  // 标签栏高度（h-10）
sidebarWidth       = 256pt // 侧边栏宽度（w-64）
aiPanelWidth       = 400pt // AI 面板宽度
sftpPanelWidth     = 500pt // SFTP 面板宽度

iconButtonSize     = 28pt  // 工具栏图标按钮（h-7 w-7）
sessionRowHeight   = 46pt  // 会话行高度
```

---

## 5. 圆角规范

### 5.1 强制规则

```
所有 RoundedRectangle 必须使用 style: .continuous（Squircle 曲线）
圆形按钮（关闭×等）必须使用 .clipShape(Circle())
禁止使用老式 .cornerRadius(n) modifier（SwiftUI 已废弃）
```

### 5.2 正确写法

```swift
// ✅ 正确
.clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
.overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5))

// ✅ 圆形
.clipShape(Circle())

// ❌ 禁止
.cornerRadius(8)
.cornerRadius(12)
RoundedRectangle(cornerRadius: 8)  // 缺少 style: .continuous
```

---

## 6. 组件规范速查

### 6.1 主要按钮（Primary Button）

```swift
背景: accentPrimary
文字: white, labelMedium
圆角: cornerRadiusSmall（8pt）, continuous
阴影: shadow-lg shadow-[accentPrimary]/30
hover: #0051d5（加深）
disabled: opacity-40
```

### 6.2 次要按钮（Ghost Button / Cancel）

```swift
背景: transparent
文字: textPrimary
圆角: cornerRadiusSmall, continuous
hover: glassMedium（bg-black/5）
```

### 6.3 工具栏按钮（Toolbar Icon Button）

```swift
尺寸: 28×28pt（h-7 w-7）
圆角: cornerRadiusSmall, continuous
背景: transparent，hover: glassMedium
图标尺寸: 14pt（h-3.5 w-3.5）
图标色: textSecondary（默认）/ accentPrimary（激活）
disabled: opacity-40
```

### 6.4 侧边栏会话行（Session Row）

```swift
内边距: px-3 py-2
圆角: cornerRadiusSmall, continuous
图标容器: p-1.5 rounded-md，bg: accentPrimary/10（默认）/ white/20（选中）
会话名: labelMedium, textPrimary（默认）/ white（选中）
地址: codeSmall SF Mono, textSecondary（默认）/ white/80（选中）
选中背景: accentPrimary，阴影: shadow-md shadow-[accentPrimary]/30
```

### 6.5 输入框（Text Field）

```swift
高度: 30pt（min）
背景: surfaceInput（bg-white/80）
边框: borderPrimary 0.5pt
圆角: cornerRadiusSmall, continuous
聚焦: borderFocus（accentPrimary/65%），shadow-md
```

### 6.6 弹窗容器（Dialog）

```swift
背景: bg-white/95 + backdrop-blur-2xl
圆角: cornerRadiusXLarge（16pt）, continuous
边框: borderPrimary 0.5pt
阴影: shadow-2xl（Shadow/XLarge）
```

### 6.7 AI 助手面板

```swift
宽度: 400pt
背景: bg-white/90 + backdrop-blur-xl
阴影: shadow-lg（右侧）
用户气泡: accentPrimary 背景，white 文字，rounded-2xl
AI 气泡: bg-white/80 + backdrop-blur-sm，borderPrimary，rounded-2xl
AI 图标: gradient from-accentPrimary to-accentIndigo
```

---

## 7. Figma → SwiftUI 转换规则

### 7.1 颜色映射

| Figma / 原型 | SwiftUI Token |
|-------------|---------------|
| `#007AFF` | `DesignTokens.Colors.accentPrimary` |
| `#5856D6` | `DesignTokens.Colors.accentIndigo` |
| `#1D1D1F` | `DesignTokens.Colors.textPrimary` |
| `#86868B` | `DesignTokens.Colors.textSecondary` |
| `#34C759` | `DesignTokens.Colors.statusConnected` |
| `#FF9500` | `DesignTokens.Colors.statusConnecting` |
| `#FF3B30` | `DesignTokens.Colors.statusError` |
| `#F5F5F7` | `DesignTokens.Colors.surfaceWindow` |
| `bg-white/95` | `DesignTokens.Colors.surfaceCard` |
| `bg-black/5` | `DesignTokens.Colors.glassMedium` |
| `#D2D2D7/50` | `DesignTokens.Colors.borderPrimary` |

### 7.2 圆角映射（Tailwind → SwiftUI）

| Tailwind | 对应 pt | SwiftUI Token |
|----------|---------|---------------|
| `rounded` | 4pt | `cornerRadiusXSmall` |
| `rounded-lg` | 8pt | `cornerRadiusSmall` |
| `rounded-xl` | 10-12pt | `cornerRadiusMedium` |
| `rounded-2xl` | 16pt | `cornerRadiusXLarge` |
| `rounded-3xl` | 24pt | `cornerRadiusXLarge + 8` |
| `rounded-full` | 999pt | `Circle()` |

### 7.3 间距映射（Tailwind → SwiftUI）

| Tailwind | px | SwiftUI Token |
|----------|----|---------------|
| `p-1` | 4px | `Spacing.xxs` |
| `p-2` | 8px | `Spacing.sm` |
| `p-3` | 12px | `Spacing.md` |
| `p-4` | 16px | `Spacing.lg` |
| `p-6` | 24px | `Spacing.xxl` |
| `gap-1` | 4px | `Spacing.xxs` |
| `gap-2` | 8px | `Spacing.sm` |
| `gap-3` | 12px | `Spacing.md` |
| `gap-4` | 16px | `Spacing.lg` |

### 7.4 阴影映射

| Tailwind | SwiftUI |
|----------|---------|
| `shadow-sm` | `Shadow/XSmall` |
| `shadow-md` | `Shadow/Small` |
| `shadow-lg` | `Shadow/Medium` |
| `shadow-xl` | `Shadow/Large` |
| `shadow-2xl` | `Shadow/XLarge` |
| `shadow-[#007aff]/30` | `accentGlow` |

---

## 8. 禁止模式（Forbidden Patterns）

```swift
// ❌ 禁止：硬编码颜色
.foregroundColor(Color(hex: "#007AFF"))
.background(Color.blue)

// ❌ 禁止：老式圆角
.cornerRadius(8)
RoundedRectangle(cornerRadius: 8)  // 无 style: .continuous

// ❌ 禁止：数字字面量间距
.padding(14)
.padding(.horizontal, 16)
HStack(spacing: 10) {}

// ❌ 禁止：硬编码尺寸
.frame(height: 32)
.frame(width: 256)

// ✅ 正确写法
.foregroundColor(DesignTokens.Colors.accentPrimary)
.clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
.padding(DesignTokens.Spacing.md)
HStack(spacing: DesignTokens.Spacing.sm) {}
.frame(height: DesignTokens.Sizes.statusBarHeight)
```

---

## 9. 项目文件结构

```
ShellMate/
├── App/
│   └── ContentView.swift          # 主窗口布局（TitleBar + Toolbar + Sidebar + Terminal + StatusBar）
├── Core/
│   ├── Persistence/               # Core Data + CloudKit
│   └── Services/
│       ├── AI/AIService.swift     # AI 服务（Claude/OpenAI/Ollama）
│       └── SSH/                   # SSH 连接引擎
├── Features/
│   ├── AI/
│   │   ├── AIAssistantPanelView.swift
│   │   └── AIErrorDetectiveView.swift
│   ├── SFTP/
│   │   └── SFTPPanelView.swift
│   ├── SessionForm/
│   │   ├── SessionFormSheet.swift
│   │   └── SessionAuthTab.swift
│   ├── Settings/
│   │   ├── AISettingsView.swift
│   │   ├── AppearanceSettingsView.swift
│   │   └── SecuritySettingsView.swift
│   ├── Sidebar/
│   │   └── SessionRowView.swift
│   ├── StatusBar/
│   │   └── TerminalStatusBarView.swift
│   ├── TabBar/
│   │   └── TerminalTabBarView.swift
│   └── Terminal/
│       └── TerminalView.swift
└── Shared/
    ├── Components/FormComponents.swift
    └── Utilities/DesignTokens.swift  ← ★ 唯一颜色/间距/尺寸来源
```

---

## 10. 版本变更记录

| 版本 | 日期 | 主要变更 |
|------|------|---------|
| v1.0 | 2026-03-22 | 初始版本，基于手写规范 |
| v2.0 | 2026-03-26 | 补充 Liquid Glass 深色玻璃规范 |
| v3.0 | 2026-03-30 | **基于 Figma Make Shell 原型全面重构** |
| | | ▸ 主色更新为 Apple `#007AFF` |
| | | ▸ 完整 Light/Dark 双模式令牌 |
| | | ▸ 状态色对齐 Apple HIG |
| | | ▸ 新增 AI 面板、SFTP 面板完整规范 |
| | | ▸ 新增工具栏 h-12、侧边栏 w-64、状态栏 h-8 尺寸 |
| | | ▸ Tailwind → SwiftUI 完整映射表 |
| | | ▸ 禁止模式清单扩充 |

---

*文档版本：v3.0 · 2026-03-30 · 基于 Figma Make fileKey: upl5OBUkpLGnOe1u5aQRZ5*
