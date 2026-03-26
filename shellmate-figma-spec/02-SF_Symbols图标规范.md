# ShellMate — SF Symbols 图标使用规范

> **文档版本：** v1.0
> **创建日期：** 2026-03-18
> **工具：** SF Symbols 5 App（[下载地址](https://developer.apple.com/sf-symbols/)）

---

## 一、SF Symbols 使用原则

### 1.1 为什么必须用 SF Symbols

- **自动对齐**：SF Symbols 与 SF Pro 字体共享同一基线和光学度量，与文字混排时完美对齐，无需手动调整
- **多权重支持**：同一图标支持 9 种字重（Ultralight 到 Black），与文字字重保持视觉一致性
- **自动深色模式**：SF Symbols 本身就是矢量，配合系统颜色自动在 Light/Dark 模式下显示正确
- **可访问性**：Screen Reader 等辅助功能能够识别并朗读 SF Symbol 的语义
- **App Store 要求**：工具栏图标使用非 SF Symbols 的自定义图标，可能导致视觉风格不一致被拒审

### 1.2 Figma 中使用 SF Symbols

1. 安装 SF Symbols 5 应用（macOS 专用，需要 Apple 开发者账号）
2. 在 Figma 中可以通过导出 SVG 后导入使用
3. **推荐插件**：`SF Symbols` Figma 插件（可直接搜索并插入）
4. 插入后将 SF Symbol SVG 转换为 Figma Component，统一管理

---

## 二、完整图标清单

### 2.1 工具栏图标（Toolbar Icons）

| 功能 | SF Symbol 名称 | 尺寸 | 字重 | 颜色 |
|------|--------------|------|------|------|
| 端口转发 | `arrow.left.arrow.right` | 14pt | Regular | Text/Tertiary |
| 命令片段 | `list.bullet.rectangle` | 14pt | Regular | Text/Tertiary |
| 同步输入 | `square.grid.2x2` | 14pt | Regular | Text/Tertiary |
| 同步输入（激活） | `square.grid.2x2.fill` | 14pt | Regular | Accent/Default |
| 设置 | `gear` | 14pt | Regular | Text/Tertiary |
| 水平分屏 | `rectangle.split.2x1` | 13pt | Regular | Text/Tertiary |
| 垂直分屏 | `rectangle.split.1x2` | 13pt | Regular | Text/Tertiary |
| 终端搜索 | `magnifyingglass` | 13pt | Regular | Text/Tertiary |
| Compose Pane | `text.alignleft` | 13pt | Regular | Text/Tertiary |
| SFTP 面板 | `folder.fill` | 13pt | Regular | Text/Tertiary |
| 录制（停止中）| `record.circle` | 13pt | Regular | Text/Tertiary |
| 录制（进行中）| `stop.circle.fill` | 13pt | Regular | Status/Error |

### 2.2 侧边栏图标（Sidebar Icons）

| 功能 | SF Symbol 名称 | 尺寸 | 字重 | 颜色 |
|------|--------------|------|------|------|
| 折叠全部 | `minus.square` | 11pt | Regular | Text/Disabled |
| 展开全部 | `plus.square` | 11pt | Regular | Text/Disabled |
| 导入 | `arrow.down.to.line` | 11pt | Regular | Text/Disabled |
| 导出 | `arrow.up.to.line` | 11pt | Regular | Text/Disabled |
| 分组展开箭头 | `chevron.down` | 8pt | Medium | Text/Disabled |
| 分组折叠箭头 | `chevron.right` | 8pt | Medium | Text/Disabled |
| 新增到分组 | `plus` | 12pt | Regular | Text/Disabled |

### 2.3 SFTP 图标（SFTP Icons）

| 功能 | SF Symbol 名称 | 尺寸 | 颜色 |
|------|--------------|------|------|
| 返回 | `chevron.left` | 12pt | Text/Tertiary |
| 前进 | `chevron.right` | 12pt | Text/Tertiary |
| 上级目录 | `chevron.up` | 12pt | Text/Tertiary |
| 刷新 | `arrow.clockwise` | 10pt | Text/Disabled |
| 上传 | `arrow.up.to.line` | 11pt | Text/Secondary |
| 下载 | `arrow.down.to.line` | 11pt | Text/Secondary |
| 新建目录 | `folder.badge.plus` | 11pt | Text/Secondary |
| 显示/隐藏 | `eye` / `eye.slash` | 11pt | Text/Secondary |
| **SFTP 面板头部图标** | **`folder.fill.badge.wifi`** | **13pt** | **Text/Tertiary** |
| **SFTP 面板折叠按钮** | **`sidebar.right`** | **13pt** | **Text/Tertiary** |
| **拖拽上传提示** | **`arrow.up.doc.fill`** | **28pt** | **Accent/Default** |

### 2.4 文件类型图标（File Type Icons）

| 文件类型 | SF Symbol 名称 | 颜色 |
|---------|--------------|------|
| 目录（文件夹）| `folder.fill` | Terminal/Cyan |
| 上级目录 `..` | `arrow.up.left.square` | Text/Disabled |
| `.js` `.ts` | `doc.text.fill` | Terminal/Yellow |
| `.json` `.yaml` `.toml` | `doc.badge.gearshape.fill` | Terminal/Green |
| `.py` | `doc.richtext.fill` | Terminal/Blue |
| `.sh` `.bash` | `terminal.fill` | Terminal/Purple |
| `.md` `.txt` | `doc.plaintext.fill` | Terminal/Blue |
| `.zip` `.gz` `.tar` | `archivebox.fill` | Amber/400 |
| `.png` `.jpg` `.svg` | `photo.fill` | Terminal/Purple |
| `.pdf` | `doc.fill` | Red/400 |
| `.env`（隐藏）| `lock.doc.fill` | Text/Disabled |
| `.gitignore`（隐藏）| `doc.fill` | Text/Disabled |
| 其他文件 | `doc.fill` | Text/Tertiary |

### 2.5 弹窗与状态图标

| 用途 | SF Symbol 名称 | 尺寸 | 颜色 |
|------|--------------|------|------|
| 警告（Amber）| `exclamationmark.triangle.fill` | 16pt | Amber/400 |
| 危险（Red）| `exclamationmark.octagon.fill` | 16pt | Status/Error |
| 成功 | `checkmark.circle.fill` | 16pt | Status/Connected |
| 信息 | `info.circle.fill` | 16pt | Accent/Default |
| SSH Key | `key.fill` | 18pt | Text/Secondary |
| 密码 | `lock.fill` | 18pt | Text/Secondary |
| SSH Agent | `person.badge.shield.checkmark.fill` | 18pt | Text/Secondary |
| 指纹 | `touchid` | 16pt | Accent/Default |
| Keychain | `key.horizontal.fill` | 14pt | Text/Secondary |
| CloudKit/iCloud | `icloud.fill` | 14pt | Accent/Default |
| 同步成功 | `checkmark.icloud.fill` | 14pt | Status/Connected |
| 同步中 | `arrow.clockwise.icloud` | 14pt | Accent/Default |
| 同步失败 | `exclamationmark.icloud.fill` | 14pt | Status/Error |

### 2.6 设置导航图标

| 设置页 | SF Symbol 名称 | 尺寸 |
|--------|--------------|------|
| 外观 | `paintbrush.fill` | 14pt |
| 关键词高亮 | `highlighter` | 14pt |
| 安全 | `lock.shield.fill` | 14pt |
| 终端 | `terminal.fill` | 14pt |
| iCloud 同步 | `icloud.fill` | 14pt |

---

## 三、图标尺寸与对齐规范

### 3.1 图标与文字混排

SF Symbols 在与文字混排时，图标尺寸应等于文字字号：

```
图标 14pt + 文字 14pt → 使用 14pt SF Symbol
图标 12pt + 文字 12pt → 使用 12pt SF Symbol

⚠️ 注意：SF Symbol 的视觉尺寸比字号略大
对于正方形图标，使用 Image(systemName:).imageScale(.small/.medium/.large) 调整
```

### 3.2 独立图标按钮

```
工具栏图标按钮（Icon-only Button）:
  点击区域: 22 × 22pt（标准），18 × 18pt（紧凑）
  图标尺寸: 13–14pt
  视觉留白: 图标在点击区域内居中，留白约 4pt

图标颜色:
  静止: Text/Tertiary（略暗，避免视觉噪音）
  悬停: Text/Primary
  激活: Accent/Default
  禁用: Text/Disabled
```

---

## 四、自定义图标规范（仅内容区域使用）

以下场景可以使用自定义 SVG 图标（不在工具栏）：

### 4.1 状态指示灯（已在 Design Tokens 中定义）

不使用图标，使用纯色圆点 + CSS/SwiftUI 动画实现。

### 4.2 标签徽章（PROD / DEV / JUMP）

纯文字，不使用图标。

### 4.3 应用图标设计建议

```
应用图标不使用 SF Symbols，需要独立设计。
参考设计方向：
  形状: 正方形，圆角由系统自动处理（不要自己画圆角）
  核心元素: 闪电符号（SSH 快速连接的隐喻）或 > 终端光标符号
  色彩: 深蓝色调为主（与 Accent 对应），避免彩虹色
  风格: 参考 iTerm2、Termius、TablePlus 的图标设计语言
  参考工具: [macOS App Icon Template](https://developer.apple.com/design/resources/)
```

---

## 五、图标禁止事项

- ❌ 不使用 Emoji 作为工具栏或菜单图标
- ❌ 不对 SF Symbol 进行拉伸或变形
- ❌ 工具栏图标不使用多色（Multicolor）SF Symbol，统一使用单色
- ❌ 不将应用内自定义 SVG 用于菜单栏 NSMenuItem 图标
- ❌ 不使用 SF Symbols 5 中标注为「Restricted」的图标（Apple 产品专属）

---

*文档版本：v1.0 · 2026-03-18*
*工具参考：SF Symbols 5 App · [Apple SF Symbols 官方文档](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)*
