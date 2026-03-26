# ShellMate — 待办事项（需外部账户/环境）

> 更新：2026-03-22
> 以下任务均因依赖外部账户或物理设备，无法在当前开发环境中自动完成。

---

## 需要 Apple Developer 账户（$99/年）

### W14.6 — TestFlight 公开测试
- 注册 Apple Developer Program
- 在 App Store Connect 创建 ShellMate 应用条目
- 上传 TestFlight 构建（基于已有 `Scripts/archive_appstore.sh`）
- 发放邀请给 ≥20 位 Beta 用户
- 收集反馈并修复 P0/P1 Bug

### W16.1 — App Store Connect 元数据
- 撰写应用描述（建议强调：零系统依赖 / Keychain 本地存储 / iCloud 同步）
- 配置关键词、分类（开发工具）、隐私政策 URL
- 设置定价与地区

### W16.2 — 截图制作
- 制作 6 张 MacBook Pro 14"/16" 截图
  1. 主窗口默认态（多会话侧边栏）
  2. 多标签页 SSH 连接中
  3. SFTP 文件管理器面板
  4. 端口转发隧道管理器
  5. 快捷命令管理器
  6. 设置面板（外观/安全）

### W16.3 — App 预览视频（可选）
- 制作 30s 操作演示视频

### W16.4 — 正式签名与公证
- 配置正式 Provisioning Profile（含 iCloud + Keychain Access Group entitlement）
- 执行 `Scripts/archive_appstore.sh` 完整流程
- `notarytool` 公证 Direct 版 DMG

### W16.5 — 正式提审
- 提交 App Store 审核（预计 1-3 个工作日）

### W16.6 — 官网 DMG 准备
- 搭建下载页，撰写更新日志

### TC-010 — iCloud 跨设备同步验收
- 在 App Store Connect 创建 CloudKit 容器（`iCloud.com.yourteam.ShellMate`）
- 更新 `ShellMate.entitlements` 中的容器 identifier
- 使用两台 Mac 执行：Mac A 新建会话 → Mac B 30s 内同步出现

---

## 需要真实 Apple Developer 证书的任务

| 任务 | 说明 |
|------|------|
| Keychain Access Group | 需正式 Provisioning Profile 才能激活 |
| iCloud Entitlement | 需正式容器 identifier |
| Push Notifications | 若后续添加同步提醒 |

---

*当 Apple Developer 账户就绪后，按 W16 → W17 顺序执行上述任务。*
