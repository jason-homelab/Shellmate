import SwiftUI

// W3 新增：SF Symbols 集中映射（ADR-005）
// 业务侧禁止 Image(systemName:) 字面量，必须经此枚举
// 详见 docs/design-specs/W0_设计规格统一交付.md §2

enum AppIcon: String, CaseIterable {

    // ── 会话操作 ─────────────────────────────────────────
    case connect            = "power.circle.fill"
    case disconnect         = "power"
    case newSession         = "plus.circle.fill"

    // ── 高级能力 ─────────────────────────────────────────
    case ai                 = "sparkles"
    case script             = "chevron.left.forwardslash.chevron.right"
    case sftp               = "folder.fill.badge.gearshape"
    case split              = "square.split.2x1"
    case tmux               = "rectangle.3.group"
    case tunnel             = "arrow.left.arrow.right.circle"
    case log                = "text.alignleft"
    case recording          = "record.circle"
    case quickCommand       = "bolt.fill"

    // ── 系统 ─────────────────────────────────────────────
    case commandPalette     = "command"
    case search             = "magnifyingglass"
    case settings           = "gearshape"
    case close              = "xmark"
    case dismiss            = "xmark.circle.fill"

    // ── 状态指示 ─────────────────────────────────────────
    case statusConnected    = "circle.fill"
    case statusConnecting   = "circle.dotted"
    case statusDisconnected = "circle"
    case statusError        = "exclamationmark.circle.fill"

    // ── Feedback level ──────────────────────────────────
    case feedbackInfo       = "info.circle.fill"
    case feedbackSuccess    = "checkmark.circle.fill"
    case feedbackWarn       = "exclamationmark.triangle.fill"
    case feedbackError      = "xmark.octagon.fill"

    // MARK: - 视图便捷
    var image: Image { Image(systemName: rawValue) }

    /// 默认 a11y label，与 AccessibilityCatalog 共享语义
    var a11yLabel: LocalizedStringKey {
        switch self {
        case .connect:            return "icon.a11y.connect"
        case .disconnect:         return "icon.a11y.disconnect"
        case .newSession:         return "icon.a11y.new_session"
        case .ai:                 return "icon.a11y.ai"
        case .script:             return "icon.a11y.script"
        case .sftp:               return "icon.a11y.sftp"
        case .split:              return "icon.a11y.split"
        case .tmux:               return "icon.a11y.tmux"
        case .tunnel:             return "icon.a11y.tunnel"
        case .log:                return "icon.a11y.log"
        case .recording:          return "icon.a11y.recording"
        case .quickCommand:       return "icon.a11y.quick_command"
        case .commandPalette:     return "icon.a11y.command_palette"
        case .search:             return "icon.a11y.search"
        case .settings:           return "icon.a11y.settings"
        case .close:              return "icon.a11y.close"
        case .dismiss:            return "icon.a11y.dismiss"
        case .statusConnected:    return "a11y.status.connected"
        case .statusConnecting:   return "a11y.status.connecting"
        case .statusDisconnected: return "a11y.status.disconnected"
        case .statusError:        return "a11y.status.error"
        case .feedbackInfo:       return "a11y.feedback.info"
        case .feedbackSuccess:    return "a11y.feedback.success"
        case .feedbackWarn:       return "a11y.feedback.warn"
        case .feedbackError:      return "a11y.feedback.error"
        }
    }
}

// MARK: - SwiftUI 渲染 helper

extension AppIcon {

    /// 渲染普通图标
    func render(size: CGFloat = 17, weight: Font.Weight = .regular) -> some View {
        image
            .font(.system(size: size, weight: weight))
            .accessibilityLabel(a11yLabel)
    }

    /// 渲染 AI 渐变填充版本
    func renderAIGradient(size: CGFloat = 17) -> some View {
        image
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(DesignTokens.Gradients.aiIcon)
            .accessibilityLabel(a11yLabel)
    }

    /// 渲染状态点（特殊小尺寸）
    func renderStatusDot(size: CGFloat = 8, color: Color) -> some View {
        image
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .accessibilityLabel(a11yLabel)
    }
}
