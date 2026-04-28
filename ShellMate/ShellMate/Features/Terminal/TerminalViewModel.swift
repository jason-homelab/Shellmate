import Foundation
import Combine

// MARK: - TerminalViewModel

/// 终端面板 ViewModel：持有面板可见性状态、服务器性能指标、AI 错误侦测、输出缓冲区。
/// TerminalController 持有此实例并委托 UI 状态更新，View 层通过 @Published 绑定。
@MainActor
final class TerminalViewModel: BaseViewModel {

    // MARK: - 面板可见性

    /// Compose Pane 是否显示
    @Published var isComposePaneOpen: Bool = false

    /// 录制对话框是否显示
    @Published var isRecordingDialogOpen: Bool = false

    // MARK: - 服务器性能指标

    /// 服务器实时性能指标（仅私钥/SSH Agent 认证时可用）
    @Published private(set) var serverMetrics: ServerMetrics?

    private var metricsMonitor: ServerMetricsMonitor?

    // MARK: - AI 错误侦探

    /// 最近检测到的错误摘要文本（非 nil 时显示错误徽章）
    @Published private(set) var detectedErrorText: String?

    private var errorOutputBuffer: String = ""

    private static let errorPatterns: [String] = [
        "command not found", "No such file or directory", "Permission denied",
        "Connection refused", "No route to host",
        ": error:", "Error:", "ERROR:", "FATAL:", "fatal error:",
        "Traceback (most recent call last)", "npm ERR!", "yarn error",
        "SyntaxError:", "NameError:", "TypeError:", "ValueError:",
        "ModuleNotFoundError:", "ImportError:", "FileNotFoundError:",
        "Exception in thread main",
    ]

    // MARK: - 输出缓冲区（AI 命令补全上下文）

    private var _outputBuffer: String = ""
    private let _outputBufferMaxChars = 32_000

    // MARK: - 性能指标管理

    func startMetricsMonitor(for session: Session, password: String?, passphrase: String?) {
        let monitor = ServerMetricsMonitor(
            session: session,
            password: password,
            passphrase: passphrase
        )
        monitor.onUpdate = { [weak self] metrics in
            self?.serverMetrics = metrics
        }
        metricsMonitor = monitor
        monitor.start()
    }

    func stopMetricsMonitor() {
        metricsMonitor?.stop()
        metricsMonitor = nil
        serverMetrics = nil
    }

    // MARK: - 输出缓冲区操作

    /// 追加终端输出到 AI 补全上下文缓冲，保持最大长度
    func updateOutputBuffer(_ text: String) {
        guard !text.isEmpty else { return }
        _outputBuffer += text
        if _outputBuffer.count > _outputBufferMaxChars {
            _outputBuffer = String(_outputBuffer.suffix(_outputBufferMaxChars))
        }
    }

    /// 返回最近终端输出（供 AI 命令补全使用）
    func recentTerminalOutput() -> String {
        _outputBuffer
    }

    // MARK: - AI 错误侦探

    func detectErrors(in text: String) {
        errorOutputBuffer += text
        if errorOutputBuffer.count > 1024 {
            errorOutputBuffer = String(errorOutputBuffer.suffix(1024))
        }
        let stripped = stripANSI(errorOutputBuffer)
        let lines = stripped.components(separatedBy: "\n")
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if Self.errorPatterns.contains(where: { trimmed.contains($0) }) {
                if trimmed != detectedErrorText {
                    detectedErrorText = String(trimmed.prefix(120))
                }
                return
            }
        }
    }

    /// 清除已检测的错误（用户手动关闭徽章后调用）
    func clearDetectedError() {
        detectedErrorText = nil
        errorOutputBuffer = ""
    }

    // MARK: - ANSI 去除工具

    func stripANSI(_ str: String) -> String {
        let pattern = "\u{1B}\\[[0-9;]*[A-Za-z]|\u{1B}\\][^\u{0007}]*\u{0007}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return str }
        let range = NSRange(str.startIndex..., in: str)
        return regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: "")
    }
}
