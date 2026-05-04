# ShellMate 端到端黑盒测试方案与验收矩阵

**版本**: v1.0.0
**对象**: ShellMate 原生桌面端程序 (.app)
**测试策略**: 基于产品功能边界与完全剥离代码细节的“输入/输出”盲测，注重极端情况网络波动和 GUI 重绘断言。

---

## 一、 测试环境与预置条件 

1. **宿主环境要求**: 
   - 硬件设定的标准 Mac 设备（Apple Silicon M1/M2/M3 及 Intel 测试机）。
   - 操作系统为 macOS 13 (Ventura) 及以上版本系统。
2. **测试沙箱搭建**: 
   - 准备1台可正常访问的 Linux 物理/虚拟测试机（正常配置 SSH 及密码、密钥访问）。
   - 准备1台人为阻断 22 端口或限制 IP 黑名单的虚拟机（用于极速测试 Error/Timeout 连接异常机制）。
3. **数据预处理**: 
   - 若测试首次体验(Onboarding)流程，需清理本地 UserDefaults：`defaults delete com.yourcompany.ShellMate`。
   - 删除 CoreData 持久化本地 SQLite 文件，清理历史 Sessions 以重置纯净状态。

---

## 二、 核心功能黑盒测试用例集 (Test Matrix)

### TC_01: 首次启动与 Welcome 界面流转 (Onboarding)
- **用例目标**: 验证应用生命周期首次打开的闭环，及刚才全新同步的英文展示层交互。
- **输入/执行步骤**:
  1. 打开全新卸载重装后的 ShellMate。
  2. 观察首屏出现的全英文界面 ("Welcome to ShellMate", "Skip", "Next")，验证 `Emoji` 动画和渐变大卡的还原度。
  3. 点击 “Next” 进入第二步，第三步动作页。
  4. 最终层分别点击 "Create Now" / "Import" / "Directly Enter"。
- **预期输出 / 断言**:
  - 点击 "Directly Enter" 能无缝淡出关闭 Welcome Sheet，并直接漏出后方带有 `No Active Sessions` 占位界面的主控制台。
  - 触发新建/导入动作时，不仅关闭 Welcome 层，且应顺畅打开 Sidebar 或新建会话表单(SessionForm)。
- **边界条件**: 重启应用不再重新弹出 Welcome Screen。

### TC_02: 会话生命周期的 CURD
- **用例目标**: 验证通过左侧边栏 (Sidebar) 维护底层 SQLite 数据的完整性与健壮性。
- **输入/执行步骤**:
  1. 通过 Terminal Placeholder 点击 `Create New Session`，或菜单栏新建连接。
  2. 填入非法/超长的 HostName、极端奇葩字符的用户名进行保存；验证保存。
  3. 执行修改（Update），篡改某个会话的认证方式从 Password 切成私钥 (Key-based)。
  4. 分组操作：构建一个深度层级（或在 Development / Production 拖拽合并文件组）。
- **预期输出 / 断言**:
  - 非法 HostName 会在系统层面报 `Connection Error` 的浮窗或状态变更，而非 App 闪退。
  - 右键会话栏能即时触发对应动作，且修改立刻在左侧 Sidebar 列表体现并排序固化，不受 Kill App 重启影响。

### TC_03: 多屏终端底层性能级并发 (Xterm & Split Screen)
- **用例目标**: TTY 渲染效率与窗口堆叠性能。
- **输入/执行步骤**:
  1. 新增一个 SSH 连接到正常服务器。
  2. 使用右上方工具栏新增 分屏（Split Screen: 左右/2x2 四格）。
  3. 在三个终端内均连接服务，并在一台中开启 `htop`，一台中执行无限大批量输出打印命令：`cat /dev/urandom | base64`。
  4. 在该负荷极大的情况下，尝试 Resize（通过拉拽 Mac 窗口边缘拉伸缩小框体）。
- **预期输出 / 断言**:
  - 窗口 Resize 时，不应发生长时间的白屏卡顿，底层应及时调用 PTY 的 `resize` 指令发出 SIGWINCH 信号将版带文字截断/折叠。
  - 工具栏上的 Metrics StatusBar（状态栏）应正确解译四屏之中 **当前聚焦选中 (Focused)** 的这台主机的 CPU 负载。

### TC_04: SSH 网络异变与抗压边界测试 (Chaos Test)
- **用例目标**: 验证底层 SSH Bridge 断联或被攻击时的应用隔离反馈。
- **输入/执行步骤**:
  1. 连接正常的 SSH session 后，主动休眠 Mac 然后立即唤醒。
  2. 连接正常的 SSH session，在目标 Linux 上物理拔掉网线，或通过 iptables 抛弃 TCP 包 `iptables -A INPUT -p tcp --dport 22 -j DROP`。
  3. 反复高频快速（30CPS 连点器）点击顶部状态栏的 Connect / Disconnect 按钮。
- **预期输出 / 断言**:
  - Mac 唤醒后，SSH Socket 连接池应感知断开 (Broken Pipe)，底部从光晕点回落成 `wifi.slash` 切断状态 (`Not connected`)，并能在 Terminal 面板抛出断开警报文本。
  - Socket Timeout 必须触发超时熔断，永远不能发生应用层面上 `ContentView` 的 UI 死锁进程（Beachball彩虹圈必须 <= 2 秒）。
  - 高频重复点击建立连接不应抛出 Zombie Process 或者发生线程挂起。

### TC_05: UI与 Figma 还原的精准回测 
- **用例目标**: 防止在未来的开发演进中破坏对已完结设计的强相关一致性。
- **验证项**:
  - 右侧工具栏排列**必须**严格确保四个图标序列： `Package`(📦) -> `Search`(🔍) -> `Clock`(🕑) -> `Settings`(⚙️)。
  - Terminal 的 Empty State（空虚态）必须出现 “No Active Sessions” 全英文，同时底部的蓝色新建按钮不允许夹带任何 `+` 号图标。
  - 状态栏：无论何时触发网络异常离线，不允许产生 "Not Connected" (大写C)，只准呈现 "Not connected" 和红灰色的断层 Link 图标。

---

## 三、 本地自动化 (XCUITest) 演进建议
在完成上述手工用例的全路径覆盖后，建议产品侧采用灰度接入 macOS XCUITest 编写自动化点击脚本。

自动化测试断言伪代码设计思路示例（以检验 UI 层为标准）：
```swift
func testEmptyStateUIBindings() throws {
    let app = XCUIApplication()
    app.launch()

    // 断言存在“无活跃会话”字眼，并且确保没有意外汉化词条渗入
    XCTAssertTrue(app.staticTexts["No Active Sessions"].exists)
    XCTAssertFalse(app.staticTexts["暂无活跃会话"].exists)

    // 断言新建按钮文本长度，如果包含左侧 icon 则长度等布局属性会异常
    let createButton = app.buttons["Create New Session"]
    XCTAssertTrue(createButton.exists)
}
```

## 四、 本轮黑盒测试验收要求
执行完毕此矩阵表格后，将上述结果填表，标记 `Pass` / `Fail` / `Blocked`，并收集崩溃过程对应的 `.crash` 苹果日志以及应用内置 Debug 级别的输出予以分析，形成测试最终质量交付。
