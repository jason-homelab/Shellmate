# libssh2 XCFramework 集成指南

## 构建产物

- `libssh2.xcframework/` - 包含 libssh2 + OpenSSL 的静态库
  - 支持架构: arm64, x86_64
  - 目标平台: macOS 13.0+
  - 包含库: libssh2 1.11.0, OpenSSL 3.2.1

## Xcode 集成步骤

### 1. 添加 XCFramework

1. 在 Xcode 中打开 ShellMate 项目
2. 选择 ShellMate Target
3. 进入 "General" 标签页
4. 在 "Frameworks, Libraries, and Embedded Content" 部分点击 "+"
5. 点击 "Add Other..." > "Add Files..."
6. 选择 `Frameworks/libssh2.xcframework`
7. 设置为 "Do Not Embed"（因为是静态库）

### 2. 配置桥接头文件

1. 选择 ShellMate Target
2. 进入 "Build Settings" 标签页
3. 搜索 "Objective-C Bridging Header"
4. 设置值为: `$(SRCROOT)/ShellMate/Core/Services/SSH/ShellMate-Bridging-Header.h`

### 3. 添加系统框架依赖

libssh2 需要以下系统框架:

1. 在 "Frameworks, Libraries, and Embedded Content" 添加:
   - `libz.tbd` (zlib 压缩)
   - `Security.framework` (加密功能)

### 4. 启用 libssh2 编译

在 "Build Settings" 中添加预处理宏:

1. 搜索 "Preprocessor Macros"
2. 添加: `LIBSSH2_ENABLED=1`

### 5. 头文件搜索路径

1. 搜索 "Header Search Paths"
2. 添加: `$(SRCROOT)/../Frameworks/libssh2.xcframework/macos-arm64_x86_64/libssh2.framework/Headers`

## 验证集成

编译项目，如果成功则表示集成完成。可以通过以下代码验证:

```swift
#if LIBSSH2_ENABLED
let version = String(cString: libssh2_version(0))
print("libssh2 版本: \(version)")
#endif
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `ShellMate-Bridging-Header.h` | Swift-C 桥接头文件 |
| `LibSSH2Bridge.swift` | Mock 实现（当前使用） |
| `LibSSH2BridgeReal.swift` | 真正的 libssh2 实现 |
| `SSHProcessBridge.swift` | 基于系统 ssh 命令的备选方案 |

## 当前状态

- ✅ XCFramework 已构建
- ✅ 桥接头文件已创建
- ✅ 真实实现代码已准备
- ⏳ 等待 Xcode 手动配置

## 切换实现

项目当前使用 `SSHProcessBridge`（基于系统 ssh 命令）作为临时方案。
完成 Xcode 配置后，可以切换到真正的 libssh2 实现。
