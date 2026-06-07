import SwiftUI

// W1 新增：语义化 a11y modifier 集合
// 业务侧不再写裸 .accessibilityLabel / .accessibilityHint，调用语义 modifier

extension View {

    // ── 连接状态点 ─────────────────────────────────────────
    func a11yConnectionStatus(_ state: ConnectionUIState) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label(for: state))
            .accessibilityHint(AccessibilityCatalog.ConnectionStatus.hint(for: state))
            .accessibilityAddTraits(.isImage)
    }

    private func label(for state: ConnectionUIState) -> LocalizedStringKey {
        switch state {
        case .connected:    return AccessibilityCatalog.ConnectionStatus.connected
        case .connecting:   return AccessibilityCatalog.ConnectionStatus.connecting
        case .disconnected: return AccessibilityCatalog.ConnectionStatus.disconnected
        case .error:        return AccessibilityCatalog.ConnectionStatus.error
        }
    }

    // ── 标签页选中态 ───────────────────────────────────────
    func a11yTabSelection(isSelected: Bool, title: String, hasActivity: Bool = false) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            .accessibilityHint(
                hasActivity
                    ? AccessibilityCatalog.Tab.activity
                    : (isSelected ? AccessibilityCatalog.Tab.selected : AccessibilityCatalog.Tab.unselected)
            )
    }

    // ── AI 对话气泡 ───────────────────────────────────────
    func a11yChatMessage(role: ChatRole, content: String, timestamp: Date? = nil) -> some View {
        let roleLabel: LocalizedStringKey = {
            switch role {
            case .user:      return AccessibilityCatalog.ChatMessage.userRole
            case .assistant: return AccessibilityCatalog.ChatMessage.assistantRole
            case .system:    return AccessibilityCatalog.ChatMessage.systemRole
            }
        }()

        return self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(roleLabel)
            .accessibilityValue(Text(content))
    }

    // ── Feedback Toast / Banner ───────────────────────────
    func a11yFeedback(level: DesignTokens.Semantic.FeedbackLevel, title: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(levelDescription(level)): \(title)"))
    }

    private func levelDescription(_ level: DesignTokens.Semantic.FeedbackLevel) -> String {
        switch level {
        case .info:    return "信息"
        case .success: return "成功"
        case .warn:    return "警告"
        case .error:   return "错误"
        }
    }

    // ── 焦点环 ─────────────────────────────────────────────
    @ViewBuilder
    func focusedRing(isFocused: Bool, cornerRadius: CGFloat = 6) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                .strokeBorder(
                    DesignTokens.Semantic.focusRing,
                    lineWidth: isFocused ? 2.5 : 0
                )
                .padding(-2)
                .allowsHitTesting(false)
        )
    }
}

// AI 对话角色（与 Features/AI 模型共享语义）
enum ChatRole {
    case user
    case assistant
    case system
}
