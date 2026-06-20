import SwiftUI

// W5 新增：连接状态覆层（解 UE-P1#16 终端"重连"按钮）
// 绑定 TerminalConnectionState，在 disconnected / reconnecting / failed 三种状态下
// 显示中央大号"重新连接"按钮 + 倒计时 + 错误诊断

struct ConnectionStateOverlay: View {

    let state: TerminalConnectionState
    let onReconnect: () -> Void
    let onCancel: () -> Void
    let onEditCredentials: () -> Void

    @State private var countdownSeconds: Int = 0
    @State private var countdownTimer: Timer?

    var body: some View {
        if state.showsReconnectOverlay {
            ZStack {
                // 半透明背景遮罩
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .transition(.opacity)

                // 中央卡片
                centerCard
                    .frame(maxWidth: 420)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            .animation(DesignTokens.Animation.spring, value: state)
            .onAppear { startAutoReconnectCountdown() }
            .onDisappear { stopCountdown() }
            .onChange(of: stateKey) { _ in
                stopCountdown()
                startAutoReconnectCountdown()
            }
        }
    }

    // MARK: - 卡片

    @ViewBuilder
    private var centerCard: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 图标
            iconSection

            // 标题
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)

            // 描述
            if let description = description {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 主操作 + 次操作
            actionsSection
                .padding(.top, DesignTokens.Spacing.xxs)
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
        .padding(.horizontal, DesignTokens.Spacing.xl + 6)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.glassBorderTop, lineWidth: 0.5)
                )
        )
        .elevation(DesignTokens.Elevation.e4)
    }

    // MARK: - 图标段

    @ViewBuilder
    private var iconSection: some View {
        ZStack {
            // 外发光
            Circle()
                .fill(accentColor.opacity(0.18))
                .frame(width: 80, height: 80)
                .blur(radius: 8)

            // 图标背景圆
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 56, height: 56)

            // 图标
            Image(systemName: iconName)
                .font(.system(size: 26, weight: .regular))
                .foregroundColor(accentColor)
        }
    }

    // MARK: - 操作段

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            // 主按钮：重新连接（含倒计时）
            Button(action: {
                stopCountdown()
                onReconnect()
            }) {
                HStack(spacing: 8) {
                    AppIcon.connect.image
                        .font(.system(size: 14, weight: .semibold))
                    if countdownSeconds > 0 {
                        Text("重新连接 (\(countdownSeconds)s)")
                    } else {
                        Text(primaryActionText)
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])

            // 次操作行
            HStack(spacing: DesignTokens.Spacing.xs) {
                if case .failed(reason: .authentication) = state {
                    secondaryButton("编辑凭据", action: onEditCredentials)
                }
                secondaryButton("取消", action: {
                    stopCountdown()
                    onCancel()
                })
            }
        }
    }

    @ViewBuilder
    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(DesignTokens.Colors.glassLight)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 状态派生

    private var accentColor: Color {
        switch state {
        case .reconnecting:          return DesignTokens.Semantic.feedbackWarnFg
        case .failed:                return DesignTokens.Semantic.feedbackErrorFg
        case .disconnected:          return DesignTokens.Colors.textSecondary
        default:                     return DesignTokens.Colors.accentPrimary
        }
    }

    private var iconName: String {
        switch state {
        case .reconnecting:          return "arrow.triangle.2.circlepath"
        case .failed:                return "xmark.octagon.fill"
        case .disconnected(reason: .networkLost): return "wifi.slash"
        case .disconnected:          return "powercord"
        default:                     return "power.circle"
        }
    }

    private var title: String {
        switch state {
        case .reconnecting(let attempt, let max):
            return "正在重新连接 (\(attempt)/\(max))"
        case .failed(reason: .authentication):
            return "认证失败"
        case .failed(reason: .hostKeyMismatch):
            return "主机密钥不匹配"
        case .failed(reason: .tcpRefused):
            return "无法连接到主机"
        case .failed:
            return "连接失败"
        case .disconnected(reason: .networkLost):
            return "网络已断开"
        case .disconnected:
            return "会话已断开"
        default:
            return ""
        }
    }

    private var description: String? {
        switch state {
        case .reconnecting:
            return "网络恢复后将自动重试，或立即重新连接"
        case .failed(reason: .authentication):
            return "用户名或密码可能已更改，请检查后重试"
        case .failed(reason: .hostKeyMismatch):
            return "服务器主机密钥与本地记录不一致，可能存在安全风险"
        case .disconnected(reason: .networkLost):
            return "检查网络连接后可立即重新连接"
        default:
            return nil
        }
    }

    private var primaryActionText: String {
        switch state {
        case .failed: return "再次尝试"
        default:      return "重新连接"
        }
    }

    // MARK: - 倒计时

    private var stateKey: String { "\(state)" }

    private func startAutoReconnectCountdown() {
        // 仅 networkLost 或 reconnecting 自动倒计时 5s
        switch state {
        case .disconnected(reason: .networkLost):
            countdownSeconds = 5
        case .reconnecting:
            countdownSeconds = 3
        default:
            return
        }
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            Task { @MainActor in
                if countdownSeconds > 0 {
                    countdownSeconds -= 1
                    if countdownSeconds == 0 {
                        timer.invalidate()
                        onReconnect()
                    }
                }
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = 0
    }
}
