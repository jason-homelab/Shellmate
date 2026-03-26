# 将缺失的文件添加到 Xcode 项目

## 背景

以下文件已创建但尚未添加到 Xcode 项目中。需要手动在 Xcode 中添加这些文件。

## 操作步骤

### 1. 打开 Xcode 项目

```bash
open ShellMate/ShellMate.xcodeproj
```

### 2. 添加 Terminal 功能文件

在 Xcode 中，找到 `Features/Terminal` 组，右键选择 "Add Files to ShellMate"，添加：

- `Features/Terminal/TerminalView.swift`
- `Features/Terminal/TerminalController.swift`
- `Features/Terminal/TerminalToolbarView.swift`
- `Features/Terminal/ShellMateTerminalView.swift`

### 3. 创建并添加 SSH 服务文件

首先在 Xcode 中创建 `Core/Services/SSH` 组：
1. 右键 `Core` 组
2. 选择 "New Group"
3. 命名为 "Services"
4. 在 Services 下再创建 "SSH" 组

然后添加以下文件：

- `Core/Services/SSH/SSHConnection.swift`
- `Core/Services/SSH/SSHSessionConfig.swift`
- `Core/Services/SSH/SSHError.swift`
- `Core/Services/SSH/SSHEventLoop.swift`
- `Core/Services/SSH/SSHNetworkUtils.swift`
- `Core/Services/SSH/SSHAuthService.swift`
- `Core/Services/SSH/SSHChannelManager.swift`
- `Core/Services/SSH/SSHProcessBridge.swift`
- `Core/Services/SSH/SSHProxyJump.swift`
- `Core/Services/SSH/LibSSH2Bridge.swift`
- `Core/Services/SSH/KnownHostsManager.swift`

### 4. 添加共享组件

在 `Shared/Components` 组中添加：

- `Shared/Components/FormComponents.swift`
- `Shared/Components/HostKeyConfirmationView.swift`
- `Shared/Components/HostKeyChangedWarningView.swift`

### 5. 修改 ContentView.swift

添加完所有文件后，修改 `App/ContentView.swift`：

将 `TerminalPlaceholderView` 替换为 `TerminalView`：

```swift
} detail: {
    if let session = sessionStore.selectedSession {
        TerminalView(session: session)  // 改用 TerminalView
    } else {
        TerminalPlaceholderView(
            session: nil,
            onConnect: nil
        )
    }
}
```

### 6. 构建验证

按 ⌘B 构建项目，确保没有错误。

## 文件清单

共需添加 18 个文件：

| 分组 | 文件名 |
|------|--------|
| Terminal | TerminalView.swift |
| Terminal | TerminalController.swift |
| Terminal | TerminalToolbarView.swift |
| Terminal | ShellMateTerminalView.swift |
| SSH | SSHConnection.swift |
| SSH | SSHSessionConfig.swift |
| SSH | SSHError.swift |
| SSH | SSHEventLoop.swift |
| SSH | SSHNetworkUtils.swift |
| SSH | SSHAuthService.swift |
| SSH | SSHChannelManager.swift |
| SSH | SSHProcessBridge.swift |
| SSH | SSHProxyJump.swift |
| SSH | LibSSH2Bridge.swift |
| SSH | KnownHostsManager.swift |
| Components | FormComponents.swift |
| Components | HostKeyConfirmationView.swift |
| Components | HostKeyChangedWarningView.swift |

## libssh2 集成（可选）

如果要使用真正的 libssh2 实现而非系统 ssh 命令：

1. 参考 `Frameworks/README.md` 的说明
2. 添加 `libssh2.xcframework` 到项目
3. 配置桥接头文件
4. 添加 `LibSSH2BridgeReal.swift`
