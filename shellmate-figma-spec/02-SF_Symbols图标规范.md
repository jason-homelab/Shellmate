# 02 — SF Symbols 图标使用规范 v3.0

> **文档版本：** v3.0（对齐 Figma Make Shell 原型，完整图标清单）
> **更新日期：** 2026-03-30
> **工具：** SF Symbols 5 App

---

## 一、图标使用原则

1. **优先使用 SF Symbols**，不自定义图标，确保 macOS 原生感
2. 图标尺寸跟随容器：工具栏 `h-3.5 w-3.5`（14pt），侧边栏 `h-3.5 w-3.5`，状态栏 `h-3 w-3`（12pt）
3. 填充类图标（`.fill`）用于状态指示，线条类用于操作按钮
4. 工具栏图标颜色默认 `textSecondary`（`#86868b` Light / `#8892AA` Dark），激活态 `accentPrimary`

---

## 二、Toolbar（工具栏）图标

| 位置 | 图标名（SF Symbols） | 对应 Lucide（原型） | 功能 | 禁用条件 |
|------|-------------------|-------------------|------|----------|
| 左 | `desktopcomputer` / `display` | `monitor` | Connect 按钮图标 | 无 |
| 左 | — （文字按钮）| — | Disconnect | 无活动会话 |
| 左 | `sparkles` | `sparkles` | AI 助手开关 | 无活动会话 |
| 左 | `chevron.left.forwardslash.chevron.right` | `code2` | 脚本自动化 | 无 |
| 左 | `folder.badge.gearshape` | `FolderSync` | 文件传输（SFTP）| 无活动会话 |
| 左 | `rectangle.split.2x1` | `SplitSquareVertical` | 分屏 | 无 |
| 左 | `doc.text` | `FileText` | 日志查看 | 无 |
| 右 | `square.and.arrow.up.on.square` | `Package` | 导入/导出 | 无 |
| 右 | `magnifyingglass` | `Search` | 全局搜索 | 无 |
| 右 | `info.circle` | `Info` | 关于/帮助 | 无 |
| 右 | `gearshape` | `Settings` | 设置 | 无 |

---

## 三、Sidebar（侧边栏）图标

| 位置 | SF Symbol | Lucide 原型 | 功能 |
|------|-----------|-------------|------|
| Header | `plus` | `Plus` | 新建会话 |
| Header | `folder.badge.gear` | `FolderCog` | 分组管理 |
| Header | `key.horizontal` | `KeyRound` | 密码管理 |
| Header | `gearshape` | `Settings` | 设置 |
| 会话行 | `display` / `server.rack` | `Server` | 会话图标 |
| 文件夹行 | `folder` | `Folder` | 分组图标 |
| 文件夹行 | `chevron.right` | `ChevronRight` | 折叠/展开指示 |

---

## 四、StatusBar（状态栏）图标

| 位置 | SF Symbol | Lucide 原型 | 语义 | 颜色 |
|------|-----------|-------------|------|------|
| 连接状态 | `wifi.slash` | `WifiOff` | 未连接 | `textSecondary` |
| CPU | `cpu` | `Cpu` | CPU 监控 | `#007aff` |
| 内存 | `memorychip` | `MemoryStick` | 内存监控 | `#5856d6` |
| 磁盘 | `externaldrive` | `HardDrive` | 磁盘监控 | `#ff9500` |
| 网络 | `wifi` | `Wifi` | 网络监控 | `#34c759` |
| 活动 | `waveform.path.ecg` | `Activity` | 连接活动 | `textSecondary` |

---

## 五、弹窗 / 面板图标

### 5.1 新建会话弹窗（Session Form）

| 字段 | SF Symbol | 说明 |
|------|-----------|------|
| 认证-密码 | `lock.fill` | 密码认证方式 |
| 认证-私钥 | `key.fill` | 私钥认证方式 |
| 认证-Agent | `person.badge.key.fill` | SSH Agent 认证 |
| 认证-键盘 | `keyboard` | 键盘交互认证 |
| Agent 可用 | `checkmark.circle.fill` | 绿色 statusConnected |
| Agent 不可用 | `xmark.circle.fill` | 红色 statusError |
| 沙盒提示 | `exclamationmark.triangle.fill` | 橙色 statusConnecting |

### 5.2 AI 助手面板

| 元素 | SF Symbol | Lucide 原型 | 说明 |
|------|-----------|-------------|------|
| 面板图标 | `sparkles` | `Sparkles` | AI 渐变图标（blue→indigo）|
| 发送按钮 | `arrow.up.circle.fill` | `Send` | 发送消息 |
| 复制命令 | `doc.on.doc` | `Copy` | 复制命令 |
| 已复制 | `checkmark` | `Check` | 复制成功（绿色）|
| 执行命令 | `terminal` | `Terminal` | 执行命令（蓝色）|
| 快速建议 | `lightbulb` | `Lightbulb` | 橙色 #ff9500 |

### 5.3 SFTP 文件传输面板

| 元素 | SF Symbol | Lucide 原型 |
|------|-----------|-------------|
| 本地 | `internaldrive` | `HardDrive` |
| 远程 | `server.rack` | `Server` |
| 文件夹 | `folder` | `FolderOpen` |
| 文件 | `doc` | `File` |
| 新建文件夹 | `folder.badge.plus` | `FolderPlus` |
| 删除 | `trash` | `Trash2` |
| 刷新 | `arrow.clockwise` | `RefreshCw` |
| 路径 | `house` | `Home` |
| 上传 | `arrow.up.to.line` | `Upload` |
| 下载 | `arrow.down.to.line` | `Download` |
| 进入目录 | `chevron.right` | `ChevronRight` |

### 5.4 设置面板

| 设置项 | SF Symbol |
|--------|-----------|
| AI 助手 | `sparkles` |
| 提供商-Claude | `sparkles` |
| 提供商-OpenAI | `circle.hexagongrid` |
| 提供商-Ollama | `desktopcomputer` |
| API Key | `key.fill` |
| 模型选择 | `cpu` |
| 功能开关 | `slider.horizontal.3` |
| 错误侦探 | `exclamationmark.triangle` |
| 安全 | `lock.shield.fill` |
| iCloud | `icloud` |

---

## 六、状态徽章图标

| 图标 | SF Symbol | 场景 |
|------|-----------|------|
| 成功 | `checkmark.circle.fill` | 操作成功（绿色）|
| 错误 | `xmark.circle.fill` | 操作失败（红色）|
| 警告 | `exclamationmark.triangle.fill` | 警告提示（橙色）|
| 信息 | `info.circle.fill` | 说明信息（蓝色）|

---

## 七、图标尺寸规范对照

| 位置 | SF Symbol font-size | SwiftUI | Lucide（原型 h-X w-X） |
|------|--------------------|---------|-----------------------|
| 工具栏图标按钮内 | system(size: 14) | `.font(.system(size: 14))` | `h-3.5 w-3.5`（14px）|
| 侧边栏行图标 | system(size: 14) | `.font(.system(size: 14))` | `h-3.5 w-3.5` |
| 状态栏图标 | system(size: 12) | `.font(.system(size: 12))` | `h-3 w-3`（12px）|
| 面板标题图标 | system(size: 16) | `.font(.system(size: 16))` | `h-4 w-4`（16px）|
| AI 面板大图标 | system(size: 20) | `.font(.system(size: 20))` | `h-5 w-5`（20px）|
| 弹窗图标 | system(size: 14) | `.font(.system(size: 14))` | `h-4 w-4` |

---

*文档版本：v3.0 · 2026-03-30*
