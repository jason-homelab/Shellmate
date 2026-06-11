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

    // ── W8 扩展：通用导航 / 操作 / 状态 ─────────────────────
    case chevronUp          = "chevron.up"
    case chevronDown        = "chevron.down"
    case chevronLeft        = "chevron.left"
    case chevronRight       = "chevron.right"
    case chevronExpand      = "chevron.up.chevron.down"
    case arrowUp            = "arrow.up"
    case arrowDown          = "arrow.down"
    case arrowLeft          = "arrow.left"
    case arrowRight         = "arrow.right"
    case arrowClockwise     = "arrow.clockwise"
    case plus               = "plus"
    case minus              = "minus"
    case checkmark          = "checkmark"
    case pencil             = "pencil"
    case copy               = "doc.on.doc"
    case folder             = "folder"
    case folderFill         = "folder.fill"
    case folderBadgePlus    = "folder.badge.plus"
    case lock               = "lock.fill"
    case lockShield         = "lock.shield"
    case key                = "key.fill"
    case keySlash           = "key.slash"
    case clock              = "clock"
    case clockArrow         = "clock.arrow.circlepath"
    case docText            = "doc.text"
    case docTextFill        = "doc.text.fill"
    case info               = "info.circle"
    case warning            = "exclamationmark.triangle"
    case shield             = "exclamationmark.shield.fill"
    case lightbulb          = "lightbulb"
    case link               = "link"
    case calendar           = "calendar"
    case desktop            = "desktopcomputer"
    case macWindow          = "macwindow"
    case cpu                = "cpu"
    case memory             = "memorychip"
    case storage            = "internaldrive"
    case networkIcon        = "network"
    case chartLine          = "chart.xyaxis.line"
    case paperPlane         = "paperplane.fill"
    case boltSlash          = "bolt.slash"
    case playFill           = "play.fill"
    case playRectangle      = "play.rectangle"
    case highlighter        = "highlighter"
    case personXmark        = "person.fill.xmark"
    case iCloudArrow        = "arrow.clockwise.icloud"
    case docUp              = "arrow.up.doc"
    case zoomIn             = "plus.magnifyingglass"
    case zoomOut            = "minus.magnifyingglass"
    case trash              = "trash"
    case serverRack         = "server.rack"
    case xmarkCircle        = "xmark.circle"

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
        // W8 扩展：装饰性图标使用通用 fallback 标签，业务侧可 override
        case .chevronUp, .chevronDown, .chevronLeft, .chevronRight, .chevronExpand,
             .arrowUp, .arrowDown, .arrowLeft, .arrowRight, .arrowClockwise,
             .plus, .minus, .checkmark, .pencil, .copy,
             .folder, .folderFill, .folderBadgePlus,
             .lock, .lockShield, .key, .keySlash,
             .clock, .clockArrow, .docText, .docTextFill,
             .info, .warning, .shield, .lightbulb, .link, .calendar,
             .desktop, .macWindow, .cpu, .memory, .storage, .networkIcon,
             .chartLine, .paperPlane, .boltSlash,
             .playFill, .playRectangle, .highlighter, .personXmark,
             .iCloudArrow, .docUp, .zoomIn, .zoomOut, .trash, .serverRack, .xmarkCircle:
            return "icon.a11y.decorative"
        }
    }
}

// MARK: - SwiftUI 渲染 helper

extension AppIcon {

    /// 装饰类图标（无独立语义，仅视觉点缀），VoiceOver 应跳过
    /// 自评 P1#6：替代原"统一 fallback label"方案，更符合 a11y 标准
    var isDecorative: Bool {
        switch self {
        case .chevronUp, .chevronDown, .chevronLeft, .chevronRight, .chevronExpand,
             .arrowUp, .arrowDown, .arrowLeft, .arrowRight, .arrowClockwise,
             .plus, .minus, .checkmark, .pencil, .copy,
             .folder, .folderFill, .folderBadgePlus,
             .lock, .lockShield, .key, .keySlash,
             .clock, .clockArrow, .docText, .docTextFill,
             .info, .warning, .shield, .lightbulb, .link, .calendar,
             .desktop, .macWindow, .cpu, .memory, .storage, .networkIcon,
             .chartLine, .paperPlane, .boltSlash,
             .playFill, .playRectangle, .highlighter, .personXmark,
             .iCloudArrow, .docUp, .zoomIn, .zoomOut, .trash, .serverRack, .xmarkCircle:
            return true
        default:
            return false
        }
    }

    /// 渲染普通图标
    /// 装饰类自动 .accessibilityHidden(true)，语义类绑定 label
    func render(size: CGFloat = 17, weight: Font.Weight = .regular) -> some View {
        image
            .font(.system(size: size, weight: weight))
            .modifier(SemanticOrHidden(label: a11yLabel, hidden: isDecorative))
    }

    /// 渲染 AI 渐变填充版本
    func renderAIGradient(size: CGFloat = 17) -> some View {
        image
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(DesignTokens.Gradients.aiIcon)
            .modifier(SemanticOrHidden(label: a11yLabel, hidden: isDecorative))
    }

    /// 渲染状态点（特殊小尺寸）
    func renderStatusDot(size: CGFloat = 8, color: Color) -> some View {
        image
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .modifier(SemanticOrHidden(label: a11yLabel, hidden: isDecorative))
    }
}

/// 自评 P1#6：根据是否装饰类，决定 a11yLabel 或 hidden
private struct SemanticOrHidden: ViewModifier {
    let label: LocalizedStringKey
    let hidden: Bool

    func body(content: Content) -> some View {
        if hidden {
            content.accessibilityHidden(true)
        } else {
            content.accessibilityLabel(label)
        }
    }
}
