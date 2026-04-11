# ShellMate UI 设计规范 v2 — Tmux 管理器（TmuxManager）

---

## 1. 弹窗预览

```
┌──────────────────────────────────────────────────────────────────┐
│  ■ Tmux Session Manager                                          │  title + Terminal icon
│  Manage and monitor tmux sessions across your servers           │  description
├──────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐          │
│  │   Sessions  │  │   Windows   │  │  Quick Actions │          │  TabsList grid-cols-3
│  └─────────────┘  └─────────────┘  └────────────────┘          │
├──────────────────────────────────────────────────────────────────┤
│  [🔄 刷新]  3 sessions                   [+ New Session]        │
│                                                                  │
│  ■ prod.example.com                                              │  Server 分组标题
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  production              [Attached]    [▶][🗑]              │ │  绿色渐变背景
│  │  3 windows · Created 10:24:15 AM                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  monitoring              [■][🗑]                            │ │
│  │  4 windows · Created Yesterday                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ■ dev.example.com                                               │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  development             [▶][🗑]                            │ │
│  │  2 windows · Created 11:30:00 AM                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
sm:max-w-[900px] max-h-[85vh] rounded-2xl
```

---

## 2. 弹窗容器规范

```css
sm:max-w-[900px] max-h-[85vh]
bg-white/95 backdrop-blur-2xl
border border-[#d2d2d7]/50 shadow-2xl rounded-2xl
overflow-hidden flex flex-col
```

---

## 3. 标题区

| 元素 | 规格 |
|------|------|
| 图标 | `Terminal h-5 w-5 text-[#34c759]` |
| 标题 | `"Tmux Session Manager"` |
| 描述 | `"Manage and monitor tmux sessions across your servers"` |

---

## 4. Sessions Tab

### 4.1 操作行

```css
flex items-center justify-between
```

| 元素 | 规格 |
|------|------|
| 刷新按钮 | `variant="outline" size="sm" rounded-lg border-[#d2d2d7]`；`RefreshCw h-3.5 w-3.5 mr-1` |
| 会话数量 | `text-xs text-[#86868b]`，"{n} session(s)" |
| 新建按钮 | `bg-[#34c759] hover:bg-[#2fb350] text-white rounded-lg`；`Plus h-4 w-4 mr-1` |

### 4.2 新建会话表单（展开态）

```css
/* Card 容器 */
bg-gradient-to-br from-[#34c759]/5 to-[#30d158]/5
border-[#34c759]/20
```

内部：
- `Label`：`text-[#1d1d1f] text-xs`，"Session Name"
- `Input`：`placeholder="e.g., my-session" bg-white border-[#d2d2d7]`
- 底部按钮：Cancel（ghost）+ Create（`bg-[#34c759]`）

### 4.3 Server 分组标题

```css
text-sm font-semibold text-[#1d1d1f] px-1
flex items-center gap-2
/* 图标 */
Terminal h-4 w-4
```

### 4.4 会话卡片

**未附加：**
```css
bg-white/80 border-[#d2d2d7]/50
hover:shadow-md transition-all duration-200
```

**已附加：**
```css
bg-gradient-to-br from-[#34c759]/10 to-[#30d158]/10
border-[#34c759]/30
```

**卡片内容：**

| 元素 | 规格 |
|------|------|
| 会话名 | `text-base text-[#1d1d1f] font-mono` |
| Attached 徽章 | `bg-[#34c759] text-white text-xs`（仅 attached 时显示） |
| 元数据 | `text-xs text-[#86868b]`："{n} window(s) · Created {时间}" |
| 附加按钮 | `Play h-4 w-4`；hover：`bg-[#34c759]/10 text-[#34c759]` |
| 分离按钮 | `Square h-4 w-4`；hover：`bg-orange-50 text-orange-600` |
| 删除按钮 | `Trash2 h-3.5 w-3.5`；hover：`bg-red-50 text-red-600` |

---

## 5. Windows Tab

**会话选择器：**
```css
Label: "Select Session:"  text-[#1d1d1f] text-sm
select: rounded-md border border-[#d2d2d7] bg-white px-3 py-1 text-sm h-9 w-full
```

**窗口卡片：**

**未激活：**
```css
bg-white/80 border-[#d2d2d7]/50
```

**激活中：**
```css
bg-gradient-to-br from-[#007aff]/10 to-[#5856d6]/10
border-[#007aff]/30
```

| 元素 | 规格 |
|------|------|
| 窗口索引徽章 | `w-8 h-8 rounded-lg bg-black/5`，内数字 `text-sm font-mono font-bold text-[#1d1d1f]` |
| 窗口名 | `text-sm text-[#1d1d1f] font-mono` |
| Pane 数量 | `text-xs text-[#86868b]`，"{n} pane(s)" |
| Active 徽章 | `bg-[#007aff] text-white text-xs` |

---

## 6. Quick Actions Tab

### 6.1 快捷操作卡片（2×2 Grid）

```css
grid grid-cols-2 gap-3
```

| 操作 | 图标 | 颜色 | 快捷键 |
|------|------|------|--------|
| Split Horizontal | `SplitSquareHorizontal` | `#007aff` | `Ctrl+B then "` |
| Split Vertical | `SplitSquareVertical` | `#34c759` | `Ctrl+B then %` |
| New Window | `Plus` | `#ff9500` | `Ctrl+B then C` |
| Zoom Pane | `Maximize2` | `#5856d6` | `Ctrl+B then Z` |

**卡片容器：**
```css
cursor-pointer hover:shadow-md transition-all duration-200
hover:border-[{颜色}]/30
```

**图标容器：**
```css
w-10 h-10 rounded-xl
bg-gradient-to-br from-[{颜色}]/10 to-[{颜色-端点}]/10
```

### 6.2 常用命令列表

分隔线 `pt-4 border-t border-[#d2d2d7]/50` 后标题 `text-sm font-semibold text-[#1d1d1f] mb-3`

每条命令：
```css
bg-white/80 rounded-lg border border-[#d2d2d7]/50
p-3 flex items-center justify-between group
hover:border-[#007aff]/30 transition-all
```

| 元素 | 规格 |
|------|------|
| 命令 | `text-xs font-mono text-[#1d1d1f] block mb-1` |
| 描述 | `text-xs text-[#86868b]` |
| 复制按钮 | `h-8 w-8 ghost`；默认 `opacity-0`，`group-hover:opacity-100`；`Copy h-3.5 w-3.5` |

预置命令：
| 命令 | 描述 |
|------|------|
| `tmux ls` | List all sessions |
| `tmux attach -t session-name` | Attach to session |
| `tmux kill-session -t session-name` | Kill session |
| `tmux rename-session -t old new` | Rename session |
