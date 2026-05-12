import Foundation
import AppKit
import SwiftTerm
import Darwin

// MARK: - 本地终端数据合并器（复用 60fps 优化策略）

private actor LocalTerminalDataCoalescer {
    private var buffer: [UInt8] = []
    private var hasPendingFlush = false

    func append(_ bytes: [UInt8]) -> Bool {
        buffer.append(contentsOf: bytes)
        if hasPendingFlush { return false }
        hasPendingFlush = true
        return true
    }

    func drain() -> [UInt8] {
        hasPendingFlush = false
        let result = buffer
        buffer = []
        return result
    }
}

// MARK: - 本地终端控制器

/// 本地终端控制器（任务 13.7）
/// 无需 SSH 连接，直接通过 POSIX PTY 运行本地 Shell（/bin/zsh 或 $SHELL）
/// 对标 iTerm2 / Terminal.app 的本地 Shell 标签页
@MainActor
final class LocalTerminalController: ObservableObject {

    // MARK: - 状态枚举

    enum State: Equatable {
        case idle
        case running
        case terminated(Int32)
    }

    // MARK: - 发布属性

    @Published private(set) var state: State = .idle
    @Published var terminalTitle: String = "本地 Shell"

    // MARK: - 内部属性

    /// SwiftTerm 视图弱引用
    weak var terminalView: SwiftTerm.TerminalView?

    private var process: Process?
    /// PTY 主端文件描述符（父进程读写端）
    private var masterFD: Int32 = -1
    /// 后台读取任务
    private var readTask: Task<Void, Never>?
    private let coalescer = LocalTerminalDataCoalescer()

    // MARK: - 生命周期

    deinit {
        if masterFD >= 0 {
            Darwin.close(masterFD)
        }
    }

    // MARK: - 启动本地 Shell

    /// 重新启动（进程退出后调用）
    func restart(shell: String? = nil) {
        process = nil
        readTask?.cancel()
        readTask = nil
        if masterFD >= 0 { Darwin.close(masterFD); masterFD = -1 }
        state = .idle
        start(shell: shell)
    }

    /// 启动本地 Shell 进程
    /// - Parameter shell: Shell 可执行路径，默认从 $SHELL 环境变量读取
    func start(shell: String? = nil) {
        guard state == .idle else { return }

        let shellPath = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        // 1. 创建 POSIX PTY（master/slave 对）
        let master = posix_openpt(O_RDWR | O_NOCTTY)
        guard master >= 0 else {
            AppLogger.ssh.error("[LocalTerm] posix_openpt 失败: \(String(cString: strerror(errno)))")
            state = .terminated(-1)
            return
        }
        guard grantpt(master) == 0, unlockpt(master) == 0 else {
            AppLogger.ssh.error("[LocalTerm] grantpt/unlockpt 失败")
            Darwin.close(master)
            state = .terminated(-1)
            return
        }
        guard let slaveNamePtr = ptsname(master) else {
            AppLogger.ssh.error("[LocalTerm] ptsname 失败")
            Darwin.close(master)
            state = .terminated(-1)
            return
        }
        let slaveName = String(cString: slaveNamePtr)
        let slave = Darwin.open(slaveName, O_RDWR)
        guard slave >= 0 else {
            AppLogger.ssh.error("[LocalTerm] 打开 slave PTY 失败: \(slaveName)")
            Darwin.close(master)
            state = .terminated(-1)
            return
        }

        masterFD = master

        // 2. 配置并启动 Shell Process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shellPath)
        // -l 表示 login shell，确保加载 .zprofile / .bash_profile 等配置
        proc.arguments = ["-l"]
        proc.environment = buildEnvironment(slaveName: slaveName)
        // 将 stdin/stdout/stderr 重定向到 PTY slave 端
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        proc.standardInput  = slaveHandle
        proc.standardOutput = slaveHandle
        proc.standardError  = slaveHandle

        proc.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                guard let self else { return }
                Darwin.close(slave)
                self.readTask?.cancel()
                self.state = .terminated(p.terminationStatus)
                AppLogger.ssh.info("[LocalTerm] Shell 进程退出，状态码: \(p.terminationStatus)")
            }
        }

        do {
            try proc.run()
        } catch {
            AppLogger.ssh.error("[LocalTerm] 启动 Shell 失败: \(error.localizedDescription)")
            Darwin.close(master)
            Darwin.close(slave)
            state = .terminated(-1)
            return
        }

        // 父进程不需要 slave 端，关闭它（子进程持有副本）
        Darwin.close(slave)
        process = proc
        state = .running

        // 3. 后台异步读取 master PTY 输出并喂给 SwiftTerm
        startReading(masterFD: master)
        AppLogger.ssh.info("[LocalTerm] 本地 Shell 启动成功: \(shellPath)")
    }

    // MARK: - PTY 读取

    private func startReading(masterFD fd: Int32) {
        readTask = Task.detached(priority: .userInitiated) { [weak self] in
            var buf = [UInt8](repeating: 0, count: 4096)
            while !Task.isCancelled {
                let n = Darwin.read(fd, &buf, buf.count)
                if n <= 0 { break }
                let bytes = Array(buf.prefix(n))
                let shouldFlush = await self?.coalescer.append(bytes) ?? false
                if shouldFlush {
                    Task { @MainActor [weak self] in
                        // 16ms 窗口合并（60fps）
                        try? await Task.sleep(nanoseconds: AppConstants.terminalCoalescerIntervalNs)
                        guard let self else { return }
                        let flushed = await self.coalescer.drain()
                        if !flushed.isEmpty {
                            self.terminalView?.feed(byteArray: flushed[...])
                        }
                    }
                }
            }
        }
    }

    // MARK: - 输入发送

    /// 将用户输入写入 PTY master 端
    func send(_ data: Data) {
        guard masterFD >= 0, state == .running else { return }
        let fd = masterFD
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            _ = Darwin.write(fd, base, ptr.count)
        }
    }

    // MARK: - PTY 尺寸调整

    /// 通知内核 PTY 窗口尺寸变化（TIOCSWINSZ）
    func resizePTY(columns: Int, rows: Int) {
        guard masterFD >= 0 else { return }
        var ws = winsize(
            ws_row: UInt16(rows),
            ws_col: UInt16(columns),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(masterFD, TIOCSWINSZ, &ws)
    }

    // MARK: - 终止

    func terminate() {
        readTask?.cancel()
        process?.terminate()
        if masterFD >= 0 {
            Darwin.close(masterFD)
            masterFD = -1
        }
    }

    // MARK: - 环境变量构建

    private func buildEnvironment(slaveName: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["TERM_PROGRAM"] = "ShellMate"
        env["COLORTERM"] = "truecolor"
        // 明确设置 TTY 设备名，供部分程序检测
        env["SSH_TTY"] = nil   // 本地终端不应伪装成 SSH
        env["COLUMNS"] = "80"
        env["LINES"] = "24"
        return env
    }
}

// MARK: - SwiftTerm TerminalViewDelegate

extension LocalTerminalController: SwiftTerm.TerminalViewDelegate {

    nonisolated func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        let d = Data(data)
        Task { @MainActor [weak self] in
            self?.send(d)
        }
    }

    nonisolated func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

    nonisolated func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.terminalTitle = title.isEmpty ? "本地 Shell" : title
        }
    }

    nonisolated func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        Task { @MainActor [weak self] in
            self?.resizePTY(columns: newCols, rows: newRows)
        }
    }

    nonisolated func bell(source: SwiftTerm.TerminalView) {
        let enabled = UserDefaults.standard.object(forKey: "terminal.bellEnabled") as? Bool ?? true
        guard enabled else { return }
        let visual = UserDefaults.standard.bool(forKey: "terminal.visualBell")
        if visual {
            Task { @MainActor in
                source.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
                Task { try? await Task.sleep(nanoseconds: 120_000_000); source.layer?.backgroundColor = .clear }
            }
        } else {
            NSSound.beep()
        }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
    nonisolated func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}
    nonisolated func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    nonisolated func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {}
    nonisolated func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}
    nonisolated func mouseModeChanged(source: SwiftTerm.TerminalView) {}
}
