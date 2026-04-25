import SwiftUI

/// 会话行视图 — 亮色 macOS 风格
/// 激活状态：全宽 Apple Blue 胶囊背景 + 白色文字（对齐 Figma Make bg-[#007aff]）
/// 图标：server.rack SF Symbol
struct SessionRowView: View {

    // MARK: - 属性

    let session: Session
    var isSelected: Bool = false
    var onDoubleClick: (() -> Void)?

    // MARK: - 状态

    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 9) {

            // ── 1. 状态点（6×6）
            statusDot

            // ── 2. 文字缩写 Avatar（26×26）
            sessionAvatar

            // ── 3. 会话信息
            sessionInfo

            Spacer(minLength: 0)
        }
        // HTML: padding: 7px 10px 7px 14px（左侧留给边栏指示器）
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(rowBackground)
        .contentShape(Rectangle())
        .opacity(isDragging ? 0.45 : 1.0)
        .scaleEffect(isDragging ? 0.97 : 1.0)
        .animation(DesignTokens.Animation.hover, value: isDragging)
        .animation(DesignTokens.Animation.hover, value: isHovering)
        .animation(DesignTokens.Animation.hover, value: isSelected)
        .onDrag {
            withAnimation(DesignTokens.Animation.hover) { isDragging = true }
            return NSItemProvider(object: session.id.uuidString as NSString)
        }
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.hover) {
                isHovering = hovering
                if !hovering { isDragging = false }
            }
        }
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name)，\(session.username)@\(session.host)")
        .accessibilityHint(isSelected ? "已选中，双击连接" : "双击连接此会话")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityValue(session.connectionState.displayName)
    }

    // MARK: - 背景

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary)
        } else if isHovering {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.Colors.surfaceHover)
        } else {
            Color.clear
        }
    }

    // MARK: - 状态点

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .shadow(color: dotGlowColor, radius: 3, x: 0, y: 0)
            .frame(width: 6, height: 6)
            .animation(DesignTokens.Animation.slow, value: session.connectionState)
    }

    private var dotColor: Color {
        if isSelected {
            switch session.connectionState {
            case .connected:    return Color.white
            case .connecting, .disconnecting: return Color.white.opacity(0.75)
            case .error:        return Color.white.opacity(0.75)
            default:            return Color.white.opacity(0.40)
            }
        }
        switch session.connectionState {
        case .connected:
            return DesignTokens.Colors.statusConnected
        case .connecting, .disconnecting:
            return DesignTokens.Colors.statusConnecting
        case .error:
            return DesignTokens.Colors.statusError
        default:
            return DesignTokens.Colors.textDisabled
        }
    }

    private var dotGlowColor: Color {
        switch session.connectionState {
        case .connected:
            return DesignTokens.Colors.statusConnected.opacity(0.70)
        default:
            return Color.clear
        }
    }

    // MARK: - 服务器图标容器

    private var sessionAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected
                    ? Color.white.opacity(0.20)
                    : DesignTokens.Colors.accentPrimary.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? Color.white.opacity(0.20)
                                : DesignTokens.Colors.accentPrimary.opacity(0.15),
                            lineWidth: 0.75
                        )
                }

            Image(systemName: "server.rack")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected
                    ? Color.white
                    : DesignTokens.Colors.accentPrimary)
        }
        .frame(width: 26, height: 26)
    }

    // MARK: - 会话信息

    private var sessionInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected
                    ? Color.white
                    : DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(session.username)@\(session.host)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(isSelected
                    ? Color.white.opacity(0.70)
                    : DesignTokens.Colors.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

}


// MARK: - 预览

#Preview("会话行状态") {
    VStack(spacing: 1) {
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .connected; return s
        }(), isSelected: true)
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .connected; return s
        }())
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .connecting; return s
        }())
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .error; return s
        }())
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .offline; return s
        }())
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 6)
    .background(DesignTokens.Colors.surfacePanel)
    .frame(width: 240)
}
