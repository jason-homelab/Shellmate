# 09 — tmux 集成 Figma 布局规范 v1.0

> **文档版本：** v1.0
> **创建日期：** 2026-04-01
> **覆盖界面：** O04 tmux 会话管理覆层 / 会话表单 tmux 配置区 / 状态栏 tmux 指示器 / 工具栏入口
> **参考文档：** PRD · 01-界面布局规范 · 07-终端覆层规范 · 05-弹窗D04D05规范

---

## 一、功能概述

### 1.1 tmux 集成定位

ShellMate 的 tmux 集成旨在为用户提供**可视化 tmux 会话管理**能力，替代手动输入 `tmux ls` / `tmux attach` 等命令。核心场景：

```
① 连接后自动检测：SSH 连接建立后检测远程 tmux 可用性及已有会话列表
② 一键附加/分离：覆层面板中点击即可附加已有 tmux 会话或创建新会话
③ 连接时自动恢复：会话配置中可设置"自动附加上次 tmux 会话"
④ 状态感知：状态栏实时显示当前 tmux 会话名及窗口数
⑤ 窗口管理：查看/切换/重命名/关闭 tmux 窗口（Window）
```

### 1.2 用户流程

```
                    ┌─────────────────┐
                    │  SSH 连接建立    │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  检测 tmux 可用  │──── 不可用 → 状态栏显示"无 tmux"
                    └────────┬────────┘
                             │ 可用
                    ┌────────▼────────┐
                    │  列出已有会话    │
                    └────────┬────────┘
                      ┌──────┴──────┐
                      │             │
              有已有会话        无已有会话
                      │             │
              ┌───────▼───────┐  ┌──▼──────────────┐
              │ 自动附加？    │  │ 自动创建新会话？ │
              │ (看会话配置)  │  │ (看会话配置)     │
              └───┬───────┬───┘  └──┬───────────┬───┘
                  │       │         │           │
                 是      否        是          否
                  │       │         │           │
            自动附加  显示覆层   自动创建     普通Shell
                      供用户选择
```

---

## 二、Screen 16 — 覆层 O04：tmux 会话管理器

### 16-A：覆层规格

```
类型: Overlay Panel（非模态，可拖拽，可调整大小）
默认尺寸: 420 × 360pt
最小尺寸: 360 × 280pt
最大尺寸: 560 × 480pt
圆角: 10pt（macOS 面板标准）
背景: Surface/Elevated
边框: Border/Default 1pt
阴影: 0 16pt 48pt rgba(0,0,0,0.6)

触发:
  - 工具栏 SF Symbol「rectangle.3.group」按钮
  - 快捷键: ⌘⇧T
  - 菜单: Tools → tmux Manager
  - 连接后自动弹出（若会话配置 tmuxAutoShow=true 且有已有会话）

关闭: Esc / 点击 × 按钮 / 再次点击工具栏按钮
定位: 终端内容区居中偏右上（距右 24pt，距上 48pt）
动画: 见 03-动效规范（缩放淡入，spring response=0.35，damping=0.75）
```

### 16-B：整体布局

```
Frame 尺寸: 420 × 360pt
布局: Vertical Auto Layout，间距 0

子区域（从上到下）:
  ① PanelHeader    420 × 44pt     标题 + 关闭按钮
  ② ToolbarRow     420 × 36pt     操作按钮行
  ③ SessionList    420 × flex-1   tmux 会话列表（可滚动）
  ④ StatusFooter   420 × 28pt     底部状态栏
```

### 16-C：面板标题栏（PanelHeader）

```
尺寸: 420 × 44pt
背景: Surface/Overlay
下边框: 1pt Border/Faint
内边距: 左 16pt 右 12pt，垂直居中

内部布局（水平，间距 0）:
  ├── 图标: SF Symbol「rectangle.3.group」14pt  Text/Tertiary
  │    右间距 8pt
  ├── 标题: "tmux 会话"  13pt SF Pro Medium  Text/Primary
  │
  ├── Spacer flex-1
  │
  ├── 服务器标签: 「ubuntu@192.168.100.167」
  │    11pt SF Mono  Text/Disabled  背景 Surface/Elevated
  │    内边距 4pt 8pt  圆角 4pt
  │    右间距 8pt
  │
  └── 关闭按钮: ×  14pt  22×22pt  圆角 4pt
        Default: Text/Disabled
        Hover:   背景 Surface/Overlay，Text/Secondary
```

### 16-D：工具栏行（ToolbarRow）

```
尺寸: 420 × 36pt
背景: Surface/Card
下边框: 1pt Border/Faint
内边距: 左 12pt 右 12pt，垂直居中

布局（水平，间距 8pt）:

左侧按钮组:
  ├── [+ 新建] Button/Bordered  高 24pt  圆角 5pt
  │     图标: SF Symbol「plus」10pt + 文字「新建」11pt  间距 4pt
  │     前景: Accent/Default
  │
  ├── [附加] Button/Plain  高 24pt
  │     图标: SF Symbol「arrow.right.to.line」10pt + 文字「附加」11pt
  │     前景: Text/Secondary
  │     禁用: 未选中任何会话时 Text/Disabled
  │
  ├── [分离] Button/Plain  高 24pt
  │     图标: SF Symbol「arrow.left.and.line.vertical.and.arrow.right」10pt + 文字「分离」11pt
  │     前景: Text/Secondary
  │     禁用: 选中会话未附加时
  │
  ├── 分割线 1pt × 16pt Border/Subtle
  │
  └── [终止] Button/Plain  高 24pt  role: destructive
        图标: SF Symbol「trash」10pt + 文字「终止」11pt
        前景: Status/Error
        禁用: 未选中任何会话时

Spacer flex-1

右侧:
  └── [刷新] IconBtn 24×24pt
        SF Symbol「arrow.clockwise」12pt  Text/Secondary
        Hover: 背景 Surface/Overlay
```

### 16-E：会话列表（SessionList）

```
尺寸: 420 × flex-1（可滚动）
背景: Surface/Window
内边距: 上下 4pt

列表项高度: 56pt（每项）
选中背景: Accent/Default opacity 12%  圆角 6pt
Hover 背景: Surface/Overlay  圆角 6pt
间距: 2pt

⚠️ 空状态:
  居中显示:
    图标: SF Symbol「rectangle.3.group」40pt  Text/Disabled
    文字: 「没有活跃的 tmux 会话」  13pt SF Pro  Text/Tertiary
    副文字: 「点击「新建」创建一个会话」  11pt SF Pro  Text/Disabled
    间距: 图标-文字 12pt  文字-副文字 4pt
```

### 16-F：会话列表项（SessionRow）

```
尺寸: flex-w × 56pt
内边距: 左 12pt 右 12pt，垂直居中
布局: 水平 Auto Layout

├── 状态指示点:
│     ● 6pt  圆角 full
│     附加中(attached): Status/Connected (#34C759) + 脉冲动画
│     未附加(detached): Status/Warning (#FF9500)
│     右间距 10pt
│
├── 主信息区（垂直 Auto Layout，间距 2pt）:
│     ├── 会话名: 「dev-server」  13pt SF Pro Medium  Text/Primary
│     │     若为当前附加: 追加 「← 当前」标签
│     │       标签: 9pt SF Pro Medium  Accent/Default
│     │       背景 Accent/Dim  圆角 3pt  内边距 2pt 6pt
│     │
│     └── 详情行（水平，间距 8pt）:
│           ├── 窗口数: SF Symbol「macwindow」10pt + 「3 窗口」  11pt  Text/Disabled
│           ├── 创建时间: SF Symbol「clock」10pt + 「2h 前」  11pt  Text/Disabled
│           └── 尺寸: 「180×50」  11pt SF Mono  Text/Disabled
│
├── Spacer flex-1
│
└── 快捷操作按钮组（Hover 时显示，opacity 0→1 过渡 150ms）:
      ├── [附加] IconBtn 24×24pt
      │     SF Symbol「arrow.right.to.line」11pt
      │     Hover: Accent/Default  背景 Accent/Dim
      │     仅 detached 状态可见
      │
      └── [分离] IconBtn 24×24pt
            SF Symbol「arrow.left.and.line.vertical.and.arrow.right」11pt
            Hover: Status/Warning  背景 Status/Warning opacity 10%
            仅 attached 状态可见
```

### 16-G：底部状态栏（StatusFooter）

```
尺寸: 420 × 28pt
背景: Surface/Toolbar
上边框: 1pt Border/Faint
内边距: 左 12pt 右 12pt，垂直居中

布局（水平）:
  ├── 统计: 「3 个会话（1 个附加中）」  10pt SF Pro  Text/Disabled
  ├── Spacer flex-1
  └── tmux 版本: 「tmux 3.4」  10pt SF Mono  Text/Disabled
```

---

## 三、Screen 17 — 新建 tmux 会话弹窗

### 17-A：弹窗规格

```
类型: Sheet（模态，附属于 tmux 管理器面板）
尺寸: 340 × 220pt
圆角: 10pt
背景: Surface/Elevated
阴影: 0 16pt 48pt rgba(0,0,0,0.6)

触发: tmux 管理器「+ 新建」按钮
关闭: Esc / 取消按钮
```

### 17-B：弹窗布局

```
Frame 尺寸: 340 × 220pt
内边距: 20pt
布局: Vertical Auto Layout，间距 16pt

├── 标题: 「新建 tmux 会话」  15pt SF Pro Semibold  Text/Primary
│
├── 表单区（Vertical，间距 12pt）:
│     ├── 会话名称:
│     │     Label: 「名称」  11pt SF Pro Medium  Text/Secondary
│     │     Input: flex-w × 28pt  12pt SF Mono
│     │     Placeholder: 「留空则使用默认编号」  Text/Disabled
│     │
│     └── 初始窗口名:
│           Label: 「窗口名」  11pt SF Pro Medium  Text/Secondary
│           Input: flex-w × 28pt  12pt SF Mono
│           Placeholder: 「可选」  Text/Disabled
│
├── Spacer flex-1
│
└── 按钮组（水平，间距 8pt，右对齐）:
      ├── [取消] Button/Plain  高 28pt
      │     「取消」  12pt  Text/Secondary
      └── [创建] Button/Bordered  高 28pt
            「创建」  12pt  Accent/Default
            快捷键: ⌘↵
```

---

## 四、会话表单 tmux 配置区

### 4.1 位置

在 SessionFormSheet 的「高级」Tab（SessionAdvancedTab）中新增「tmux」分组，位于「Keep Alive」设置项下方。

### 4.2 布局

```
Section: 「tmux 集成」
  图标: SF Symbol「rectangle.3.group」  Text/Tertiary

├── [启用 tmux 集成] Toggle
│     Label: 「连接后自动检测 tmux」  12pt SF Pro  Text/Primary
│     Subtitle: 「SSH 连接建立后自动检查 tmux 可用性」  11pt  Text/Disabled
│     Default: ON
│
├── [自动附加策略] Picker（启用 tmux 时可见）
│     Label: 「自动附加」  12pt SF Pro  Text/Primary
│     选项:
│       ├── 「不自动附加」    ← 默认
│       ├── 「附加最近使用的会话」
│       ├── 「附加指定会话名」
│       └── 「创建新会话」
│
├── [指定会话名] TextField（策略为「附加指定会话名」时可见）
│     Label: 「会话名」  12pt SF Pro  Text/Primary
│     Input: flex-w × 28pt  12pt SF Mono
│     Placeholder: 「例如: dev」  Text/Disabled
│
├── [默认新会话名] TextField（策略为「创建新会话」时可见）
│     Label: 「新会话名」  12pt SF Pro  Text/Primary
│     Input: flex-w × 28pt  12pt SF Mono
│     Placeholder: 「留空则使用默认编号」  Text/Disabled
│
└── [断开时行为] Picker
      Label: 「SSH 断开时」  12pt SF Pro  Text/Primary
      选项:
        ├── 「仅分离（保留 tmux 会话）」  ← 默认
        └── 「终止 tmux 会话」
```

---

## 五、状态栏 tmux 指示器

### 5.1 位置

在 TerminalStatusBarView 的连接信息区右侧，资源监控区左侧插入 tmux 状态区段。

### 5.2 布局

```
tmux 状态区段（水平 Auto Layout，间距 4pt）:

├── tmux 图标: SF Symbol「rectangle.3.group」10pt
│     颜色规则:
│       - 已附加 tmux: Status/Connected (#34C759)
│       - 有会话但未附加: Status/Warning (#FF9500)
│       - tmux 不可用: Text/Disabled
│
├── 会话标签:
│     格式: 「tmux:dev-server」  10pt SF Mono
│     颜色: Text/Secondary
│     点击: 打开 tmux 管理器覆层
│
├── 窗口指示器（已附加时可见）:
│     格式: 「[2/5]」  10pt SF Mono  Text/Disabled
│     含义: 当前第 2 个窗口 / 共 5 个窗口
│     点击: 展开窗口快速切换菜单
│
└── 分割线: | 1pt × 12pt  Border/Subtle  左右 margin 4pt

窗口快速切换菜单（点击 [2/5] 展开）:
  类型: Popover  宽度 200pt  最大高度 240pt
  背景: Surface/Elevated  圆角 8pt
  阴影: shadow-medium

  列表项（每项 28pt）:
    ├── 窗口编号: 「0:」  10pt SF Mono  Text/Disabled  宽 20pt
    ├── 窗口名: 「bash」  11pt SF Pro  Text/Primary
    ├── Spacer
    └── 活跃标记: 「*」  11pt SF Pro Bold  Accent/Default（当前窗口）
```

---

## 六、工具栏入口

### 6.1 按钮位置

在 Toolbar 左侧操作区，SFTP 按钮（`folder.badge.gearshape`）右侧添加 tmux 按钮。

### 6.2 按钮规格

```
SF Symbol: 「rectangle.3.group」
尺寸: 与工具栏其他图标按钮一致（h-3.5 w-3.5, 14pt）
快捷键: ⌘⇧T

状态颜色:
  - 默认（无 tmux / 未连接）: Text/Secondary (#86868b)
  - 激活（已附加 tmux）: Status/Connected (#34C759)
  - 警告（有会话未附加）: Status/Warning (#FF9500)
  - 禁用（无活动连接）: Text/Disabled

Tooltip: 「tmux 会话管理器 (⌘⇧T)」
```

---

## 七、交互细节

### 7.1 连接后自动检测流程

```
时序:
  1. SSH 连接成功 → TerminalController 回调
  2. 延迟 500ms（等待 shell prompt 稳定）
  3. 静默执行: `tmux -V 2>/dev/null && echo "__TMUX_OK__" || echo "__TMUX_NA__"`
  4. 解析输出:
     - __TMUX_OK__ → tmux 可用，执行 `tmux ls -F "#{session_name}|#{session_attached}|#{session_windows}|#{session_created}"`
     - __TMUX_NA__ → tmux 不可用，状态栏显示灰色图标
  5. 根据会话配置执行自动附加策略
  6. 更新工具栏图标颜色 + 状态栏指示器
```

### 7.2 附加操作

```
用户点击「附加」→ 发送 `tmux attach-session -t <session_name>\n` 到终端
  - 终端进入 tmux 模式
  - 状态栏更新为绿色 tmux 指示器
  - 工具栏图标变为绿色
```

### 7.3 分离操作

```
用户点击「分离」→ 发送 tmux prefix + d（默认 Ctrl-B d）
  或直接发送 `tmux detach-client\n`
  - 终端退出 tmux 模式
  - 状态栏更新为橙色（有会话未附加）
  - 自动刷新会话列表
```

### 7.4 终止操作

```
用户点击「终止」→ 弹出确认弹窗:
  「确认终止 tmux 会话 "dev-server"？此操作不可撤销，会话中的所有进程将被终止。」
  [取消] [终止]（destructive）
  确认后发送: `tmux kill-session -t <session_name>\n`
```

### 7.5 键盘快捷键

| 快捷键 | 作用域 | 功能 |
|--------|--------|------|
| ⌘⇧T | 全局（有活动连接） | 打开/关闭 tmux 管理器 |
| ⌘↵ | 新建会话弹窗 | 确认创建 |
| Delete | tmux 管理器（选中会话） | 终止会话（需确认） |
| ↵ | tmux 管理器（选中会话） | 附加选中会话 |

---

## 八、SF Symbols 图标清单

| 元素 | SF Symbol | 用途 | 备选 |
|------|-----------|------|------|
| tmux 管理器图标 | `rectangle.3.group` | 面板标题、工具栏、状态栏 | `rectangle.split.3x1` |
| 新建会话 | `plus` | 工具栏「新建」按钮 | — |
| 附加会话 | `arrow.right.to.line` | 附加操作按钮 | `arrow.right.to.line.compact` |
| 分离会话 | `arrow.left.and.line.vertical.and.arrow.right` | 分离操作按钮 | `escape` |
| 终止会话 | `trash` | 终止操作按钮（destructive） | `xmark.circle` |
| 刷新列表 | `arrow.clockwise` | 工具栏刷新按钮 | — |
| 窗口数量 | `macwindow` | 会话行详情 | `uiwindow.split.2x1` |
| 创建时间 | `clock` | 会话行详情 | `clock.arrow.circlepath` |
| tmux 不可用 | `exclamationmark.triangle` | 状态提示 | — |

---

## 九、设计检查清单

- [ ] O04 覆层在终端 Light/Dark 模式下均可读
- [ ] tmux 管理器支持键盘导航（↑↓ 选择，↵ 附加）
- [ ] 会话列表空状态有明确引导
- [ ] 状态栏 tmux 区段不超过 160pt 宽度，超长会话名截断
- [ ] 工具栏 tmux 按钮在无活动连接时正确禁用
- [ ] 新建会话弹窗 Tab 焦点顺序正确（名称→窗口名→创建按钮）
- [ ] 终止操作有确认弹窗，防止误操作
- [ ] 窗口快速切换 Popover 支持滚动（超过 8 个窗口时）
- [ ] VoiceOver 标签：tmux 管理器按钮 = "tmux session manager"
- [ ] 所有文本支持中英双语（Localizable.strings）

---

*文档版本：v1.0 · 2026-04-01*
*关联文档：01-界面布局规范 · 07-终端覆层规范 · 05-弹窗D04D05规范*
