import SwiftUI

// MARK: - WelcomeViewModel
//
// 欢迎界面状态管理与业务逻辑，负责：
//   • 当前步骤索引（currentStep）
//   • 步骤数据与功能特性数据
//   • 步骤跳转、导航、外部回调分发

@MainActor
final class WelcomeViewModel: BaseViewModel {

    // MARK: - 步骤数据模型

    struct StepData {
        let emoji: String
        let gradientColors: [Color]
        let title: String
        let description: String
    }

    // MARK: - 特性卡片数据模型（Figma-Spec-v2 §13 §5.1 六张特性卡片）

    struct FeatureData: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let description: String
    }

    // MARK: - 状态

    @Published var currentStep: Int = 0

    // MARK: - 静态数据（对齐 Figma-Spec-v2 §13 中文文案）

    let steps: [StepData] = [
        StepData(
            emoji: "👋",
            gradientColors: [Color.blue.opacity(0.10), Color.purple.opacity(0.10)],
            title: "欢迎使用 ShellMate",
            description: "专业的 macOS SSH 会话管理工具，为开发者和运维工程师而生。"
        ),
        StepData(
            emoji: "🚀",
            gradientColors: [Color.green.opacity(0.10), Color.blue.opacity(0.10)],
            title: "强大的核心功能",
            description: "一切你需要的专业 SSH 工具箱，尽在 ShellMate。"
        ),
        StepData(
            emoji: "⚡",
            gradientColors: [Color.orange.opacity(0.10), Color.red.opacity(0.10)],
            title: "一切就绪！",
            description: "立即添加您的第一个 SSH 会话，开始使用 ShellMate。"
        )
    ]

    // 六张特性卡片（对齐 Figma-Spec-v2 §13 §5.1）
    let features: [FeatureData] = [
        FeatureData(icon: "lock.shield.fill",      label: "安全连接", description: "Keychain 加密，密钥管理"),
        FeatureData(icon: "bolt.fill",             label: "快速切换", description: "多会话标签，一键切换"),
        FeatureData(icon: "sparkles",              label: "AI 助手",  description: "Claude 驱动，智能命令建议"),
        FeatureData(icon: "arrow.up.arrow.down",   label: "文件传输", description: "SFTP 双面板，拖放上传"),
        FeatureData(icon: "rectangle.split.2x1",  label: "tmux 管理", description: "可视化 session 和 window 管理"),
        FeatureData(icon: "network",               label: "隧道转发", description: "本地/远程/SOCKS5 端口映射")
    ]

    // MARK: - 回调

    var onDismiss: (() -> Void)?
    var onCreateSession: (() -> Void)?
    var onImportConfiguration: (() -> Void)?

    // MARK: - 初始化

    init(
        onDismiss: (() -> Void)? = nil,
        onCreateSession: (() -> Void)? = nil,
        onImportConfiguration: (() -> Void)? = nil
    ) {
        self.onDismiss = onDismiss
        self.onCreateSession = onCreateSession
        self.onImportConfiguration = onImportConfiguration
    }

    // MARK: - 操作

    func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
    }

    func prevStep() {
        withAnimation(.easeInOut(duration: 0.3)) { currentStep -= 1 }
    }

    func goToStep(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.3)) { currentStep = index }
    }

    func skip() { onDismiss?() }
    func createSession() { onCreateSession?() }
    func importConfiguration() { onImportConfiguration?() }
}
