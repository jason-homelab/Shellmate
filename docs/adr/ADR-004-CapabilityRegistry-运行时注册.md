# ADR-004：CapabilityRegistry 运行时注册 vs 编译时配置

**状态**：已采纳
**日期**：2026-06-07

## 背景

CapabilityRegistry 收纳全部高级能力（AI / SFTP / Tmux / Tunnel / Script / Recording / Log / QuickCommand），供 ⌘K 命令面板、工具栏、Onboarding 三处共享。

## 决策

**运行时注册**。各 Feature 模块在 App 启动时（`ShellMateApp.init` 或 Feature-Bootstrap）调用 `CapabilityRegistry.shared.register(...)`。

## 理由

1. **Feature 自治**：Feature 自己描述能力（标题、快捷键、触发条件），不需要 Core 配置
2. **可条件化**：能力可基于 build target 注册（App Store 版屏蔽 SSH Agent 入口）
3. **支持插件化未来**：架构 §9 长期视图的第三方扩展从同一接口接入
4. **简化测试**：单测可注入 mock Registry

## 后果

- ✅ 新 Feature 增加一行 `register` 即接入三处 UI
- ⚠️ 启动顺序需明确：所有 register 必须在 App 进入 main window 之前完成
- ⚠️ Capability id 重复需 fatalError 防御
