# ShellMate — 可访问性规范 & Figma Handoff 检查清单

> **文档版本：** v1.0
> **创建日期：** 2026-03-18

---

## 一、可访问性核心要求

### 1.1 对比度标准（WCAG 2.1 AA）

所有文字与背景色的对比度必须通过以下检查：

| 文字类型 | 最低对比度 | 推荐对比度 |
|---------|-----------|-----------|
| 正文（< 18pt）| 4.5 : 1 | ≥ 7 : 1 |
| 大文字（≥ 18pt 或 14pt Bold）| 3 : 1 | ≥ 4.5 : 1 |
| UI 组件边框 | 3 : 1 | — |
| 图标（独立传达信息时）| 3 : 1 | — |

**ShellMate 关键颜色对比度验证：**

| 前景色 | 背景色 | 模式 | 对比度 | 是否通过 |
|--------|--------|------|--------|---------|
| Text/Primary `#EEEDF5` | Surface/App `#0C0C0E` | Dark | 16.8 : 1 | ✅ AAA |
| Text/Secondary `#9D9CAA` | Surface/App `#0C0C0E` | Dark | 5.2 : 1 | ✅ AA |
| Text/Tertiary `#5C5B68` | Surface/App `#0C0C0E` | Dark | 2.8 : 1 | ⚠️ 不用于正文 |
| Status/Connected `#2DCE7A` | Surface/App `#0C0C0E` | Dark | 7.1 : 1 | ✅ AAA |
| Status/Error `#F04060` | Surface/App `#0C0C0E` | Dark | 4.6 : 1 | ✅ AA |
| Terminal/Dim `#74738A` | Terminal/Background `#0C0C0E` | Dark | 3.8 : 1 | ✅ AA Large |
| Text/Primary `#1A1A1A` | Surface/App `#FFFFFF` | Light | 18.1 : 1 | ✅ AAA |
| Text/Secondary `#5C5C5C` | Surface/App `#FFFFFF` | Light | 7.5 : 1 | ✅ AAA |

**⚠️ 注意：** `Text/Tertiary`（`#5C5B68` 深色模式）对比度 2.8:1 不满足正文要求，**只能用于辅助性、非关键信息**（如分组标题、占位符、状态栏），不能用于主要内容文字。

**Text/Tertiary 合规使用清单（已审查）：**

| 使用位置 | 是否合规 | 说明 |
|---------|---------|------|
| 表单 Label 标题（Uppercase 小字） | ✅ 合规 | 辅助性标签，非正文 |
| 分组折叠箭头图标 | ✅ 合规 | 图标状态指示，非文字 |
| 状态栏分隔符 | ✅ 合规 | 纯装饰 |
| SFTP 面包屑路径（非当前目录段） | ⚠️ 边界 | 字体 10.5pt SF Mono，建议升级为 Text/Secondary |
| SFTP 列表 ColumnHeader 列名 | ⚠️ 边界 | Uppercase 10pt，建议升级为 Text/Secondary |
| D01 弹窗 Tab 非激活项 | ⚠️ 边界 | 12pt 可点击元素，建议升级为 Text/Secondary |

**修订规则：** 所有 10pt 以上的可交互元素（按钮、Tab 项、可点击列标题），一律使用 Text/Secondary（5.2:1 ✅）而非 Text/Tertiary。

### 1.2 颜色不能是唯一信息载体

以下状态信息不能仅靠颜色区分，必须配合图标或文字：

| 状态 | 颜色 | 必须同时提供 |
|------|------|------------|
| 连接状态（绿/黄/灰）| 是 | StatusDot 形状 + 文字（状态栏）|
| 错误输入（红色边框）| 是 | 错误图标 + 错误文字说明 |
| 传输完成（绿色进度条）| 是 | ✓ 图标 + "完成"文字 |
| 安全警告（D03 红色边框）| 是 | 警告图标 + 标题文字 |

### 1.3 VoiceOver 标注规范

在 Figma 标注层中，每个交互元素需要添加 VoiceOver 描述：

```
格式: 【VO】[角色] [标签] [值] [提示]
示例:
  【VO】Button "新建会话" — 点按以创建新 SSH 会话
  【VO】Button "prod-web-01，已连接" — 双击以打开终端
  【VO】Image "✓" — iCloud 已同步，上次同步：刚刚
  【VO】TextField "主机地址" required — 输入服务器 IP 或域名
  【VO】Checkbox "自动重连" checked — 断连后自动重试
```

### 1.4 键盘导航要求

**Tab 键焦点顺序（弹窗 D01 为例）：**

```
1. 会话名称输入框
2. 主机地址输入框
3. 端口输入框
4. 用户名输入框
5. 分组下拉菜单
6. 备注输入框
7. 取消按钮
8. 测试连接按钮
9. 保存并连接按钮（默认焦点，Enter 触发）
```

**必须支持的键盘交互：**

| 快捷键 | 行为 |
|--------|------|
| `Tab` / `⇧Tab` | 在可交互元素间循环聚焦 |
| `Return` / `Space` | 触发聚焦按钮 |
| `Esc` | 关闭 Sheet / Alert（除 D03 P0 强制弹窗外）|
| `⌘N` | 新建会话 |
| `⌘T` | 新标签页 |
| `⌘W` | 关闭当前标签页 |
| `⌘F` | 终端内搜索 |
| `⌘,` | 打开设置 |
| `⌘⌥S` | 收起/展开侧边栏 |
| `⌘⇧S` | 切换 SFTP 面板 |
| 方向键 | 在列表中移动选中项 |

---

## 二、Figma Handoff 完整检查清单

### ✅ Phase 1：Design Tokens 检查

- [ ] Variables 已建立（Collections: Primitives / Semantic / Accent）
- [ ] 每个变量都有 Light 和 Dark 两个 Mode 值
- [ ] 切换 Mode 后所有界面视觉正确，无颜色遗漏
- [ ] 无任何硬编码 hex 颜色（除 Primitives 层外）
- [ ] Accent/Default 标注「代码中替换为 Color.accentColor」
- [ ] Text Styles 已建立，所有文字使用 Text Style，无裸字体设置
- [ ] Vibrancy 区域已用专属标注层说明

### ✅ Phase 2：组件完整性检查

- [ ] 所有 Button 变体完整（Default / Hover / Pressed / Disabled）
- [ ] 所有 Input 变体完整（Default / Focus / Filled / Error）
- [ ] 所有 SessionRow 变体完整（Connected / Connecting / Offline / Selected / Hover）
- [ ] 所有 Tab 变体完整（Active / Inactive / Hover）
- [ ] Context Menu 包含 Divider 和 Destructive 变体
- [ ] Tooltip 完整（普通 / 技术信息双列型）
- [ ] 所有组件使用 Auto Layout
- [ ] 所有组件内 constraints 设置正确

### ✅ Phase 3：Screen 完整性检查

**主窗口：**
- [ ] 默认状态（侧边栏展开，SFTP 隐藏）
- [ ] 侧边栏折叠状态
- [ ] SFTP 面板展开状态
- [ ] 左右分屏状态
- [ ] 上下分屏状态
- [ ] Compose Pane 展开状态
- [ ] 快捷命令栏折叠状态
- [ ] 终端内搜索覆层显示状态
- [ ] 同步输入模式（橙色边框高亮）

**弹窗（每个弹窗的所有 Tab/State）：**
- [ ] D01 新建会话（4 个 Tab × 各自完整状态）
- [ ] D02 指纹确认（含随机艺术图占位）
- [ ] D03 密钥变更警告（P0 样式）
- [ ] D04 端口转发管理器（含详情编辑状态）
- [ ] D05 快捷命令管理器（含命令选中编辑状态）

**设置界面（5 个页面，对应 06-设置面板规范.md）：**
- [ ] S02 外观（主题预览缩略图 × 8 + 字体/光标/窗口配置）
- [ ] S01 关键词高亮（规则集列表 + 规则详情 + 内联添加表单）
- [ ] S03 安全（Known Hosts 表格 + SSH 密钥列表 + 主密码设置）
- [ ] S04 终端行为（滚动缓冲区 + 编码与输入 + 日志 + 高级）
- [ ] S05 iCloud 同步（总开关 + 同步范围 + 同步状态 + 冲突解决）

### ✅ Phase 4：可访问性检查

- [ ] 所有对比度通过 WCAG 2.1 AA（使用 Figma 插件 A11y 或手动验证）
- [ ] 状态信息不仅靠颜色传达（均配有图标或文字）
- [ ] 所有交互元素有 VoiceOver 标注
- [ ] 键盘 Tab 焦点顺序在弹窗标注中已说明
- [ ] 动效均有 Reduce Motion 降级方案

### ✅ Phase 5：开发 Handoff 标注检查

每个组件和界面必须有以下标注（使用 Figma Dev Mode 或标注文本图层）：

```
必要标注项:
  【SwiftUI 组件】对应组件名
  【颜色变量】使用的 Variable 名 → 对应 NSColor/SwiftUI Color
  【字体】Text Style 名 → .system(size:weight:design:)
  【动效】触发条件，持续时间，曲线
  【Vibrancy】如适用，说明 NSVisualEffectView material
  【交互】点击/双击/右键行为说明
  【Reduce Motion】动效降级说明
  【VoiceOver】无障碍读屏标签
```

---

## 三、Light Mode 设计要求

当前所有规范文档默认以 Dark Mode 描述。Light Mode 是 **必须交付** 的设计变体，缺少 Light Mode 会导致用户在系统切换外观时界面出现视觉异常。

### 3.1 Light Mode 完整语义颜色映射表

以下为所有 Semantic Token 在 Light Mode 下的对应值（供 Figma Variables 的 Light Mode 配置）：

| Token | Dark Mode | Light Mode |
|-------|-----------|------------|
| `Surface/App` | `#0C0C0E` | `#F2F2F7`（系统标准灰背景）|
| `Surface/Window` | `#141418` | `#FFFFFF` |
| `Surface/Sidebar` | Vibrancy/Dark | Vibrancy/Light |
| `Surface/Panel` | `#1C1C22` | `#F7F7FA` |
| `Surface/Toolbar` | `#222228` | `#EBEBF0` |
| `Surface/Elevated` | `#2A2A32` | `#FFFFFF` |
| `Surface/Overlay` | `#303038` | `#F0F0F5` |
| `Surface/Input` | `#1A1A20` | `#FFFFFF` |
| `Border/Faint` | `rgba(255,255,255,0.04)` | `rgba(0,0,0,0.06)` |
| `Border/Subtle` | `rgba(255,255,255,0.08)` | `rgba(0,0,0,0.10)` |
| `Border/Default` | `rgba(255,255,255,0.12)` | `rgba(0,0,0,0.15)` |
| `Text/Primary` | `#EEEDF5` | `#1A1A1A` |
| `Text/Secondary` | `#9D9CAA` | `#5C5C5C` |
| `Text/Tertiary` | `#5C5B68` | `#8E8E93` |
| `Text/Disabled` | `#3C3B48` | `#C7C7CC` |
| `Terminal/Background` | `#0C0C0E` | `#FAFAFA`（用户可在主题中自定义）|
| `Status/Connected` | `#2DCE7A` | `#1E8C52`（Light 下加深保持对比度）|
| `Status/Error` | `#F04060` | `#D0293E` |
| `Status/Connecting` | `#F5A623` | `#C47D10` |
| `Accent/Dim` | `rgba(61,142,240,0.15)` | `rgba(0,122,255,0.10)` |
| `Accent/Glow` | `rgba(61,142,240,0.08)` | `rgba(0,122,255,0.06)` |

### 3.2 Light Mode 关键界面适配要点

**终端区域（Light Mode 特殊处理）：**
- 终端背景即使在 Light Mode 下也允许保持深色（用户通常偏好深色终端）
- 终端边框 `1pt Border/Default（Light）` 区隔终端与浅色 UI 背景
- Terminal/Dim `#74738A` 在白底对比度不足（2.6:1），Light Mode 下改为 `#595959`（6.5:1 ✅）

**侧边栏 Vibrancy（Light Mode）：**
- 使用 `NSVisualEffectView` material `.sidebar`，Light Mode 下自动呈现浅色磨砂效果
- 侧边栏文字色自动切换（系统 NSColor 语义色会跟随模式）

**连接状态指示灯（Light Mode）：**
- 绿色状态点改用 `#1E8C52`（对比度 6.8:1 vs 白底 ✅）
- 红色改用 `#D0293E`（对比度 5.1:1 ✅）

**Figma 实施步骤：**
```
1. 在 Figma Variables 面板 → Collections → Semantic
2. 添加「Light」Mode 列
3. 将上表右列值逐一填入对应变量的 Light Mode
4. 使用 View → Presentation → Light/Dark 切换验证所有 Screen
5. 每个 Screen 截图对比，检查颜色遗漏（硬编码 hex 不会跟随切换）
```

### 3.3 Light Mode 注意事项

- 侧边栏 Vibrancy 在 Light Mode 下更显著（透出浅色桌面壁纸），设计中需考虑内容的可读性
- 终端在 Light Mode 下，`Terminal/Dim` 颜色需重新调整为 `#595959`
- 状态绿色在 Light Mode 下使用 `Status/Connected Light`（更深的绿：`#1E8C52`）
- `Text/Tertiary` 在 Light Mode 下对应 `#8E8E93`，对比度 2.5:1，**同样只能用于辅助性非正文内容**

---

## 四、9 种强调色变体展示页

Figma 中必须有一个「Theme Preview」页面，展示 9 种系统强调色下 ShellMate 的外观：

```
强调色列表（macOS Ventura 系统选项）:
  1. 蓝色 Blue         #3D8EF0（设计稿默认参考）
  2. 紫色 Purple       #9B59B6
  3. 粉色 Pink         #E91E8C
  4. 红色 Red          #E53935
  5. 橙色 Orange       #FF6D00（最常用选项之一）
  6. 黄色 Yellow       #F9A825
  7. 绿色 Green        #43A047
  8. 石墨 Graphite     #6E6E6E
  9. 多彩 Multicolor   [系统自动选择]

展示方式:
  每种颜色展示一个缩略版主窗口（400×260pt）
  重点展示: 主按钮颜色 / 侧边栏选中高亮 / 标签页激活线 / 输入框聚焦环
  标注: "以上颜色均由系统强调色偏好决定，代码使用 Color.accentColor"
```

---

*文档版本：v1.0 · 2026-03-18*
*参考工具：Figma A11y Checker 插件 · [Apple Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)*
