import SwiftUI

/// 会话行视图 — Operator Dark v2 设计
/// 激活状态：左 2px teal 边栏光晕 + 右侧 0 圆角背景（border-radius: 0 8 8 0）
/// 图标：会话名文字缩写 Avatar（取前两个单词首字母）
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
        // 激活状态左边栏指示器（teal 竖条 + 光晕）
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(DesignTokens.Colors.accentPrimary)
                    .frame(width: 2)
                    .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.55), radius: 5, x: 0, y: 0)
                    .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.25), radius: 12, x: 0, y: 0)
            }
        }
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
            // 激活态：右侧有圆角，左侧直角（配合边栏指示器）
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 8,
                topTrailingRadius: 8,
                style: .continuous
            )
            // Apple Blue 0.12 — 对齐 Figma selected row
            .fill(DesignTokens.Colors.accentPrimary.opacity(0.12))
        } else if isHovering {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.05))
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
        switch session.connectionState {
        case .connected:
            return DesignTokens.Colors.statusConnected   // #34d399
        case .connecting, .disconnecting:
            return DesignTokens.Colors.statusConnecting  // 琥珀黄
        case .error:
            return DesignTokens.Colors.statusError       // 玫瑰红
        default:
            return Color.white.opacity(0.12)             // idle: 很淡的白
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

    // MARK: - 服务器图标容器（Figma-Spec-v2 §02 §4.1：server.rack 14pt）

    private var sessionAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected
                    ? DesignTokens.Colors.accentPrimary.opacity(0.15)
                    : Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? DesignTokens.Colors.accentPrimary.opacity(0.25)
                                : Color.white.opacity(0.06),
                            lineWidth: 0.75
                        )
                }

            Image(systemName: "server.rack")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected
                    ? DesignTokens.Colors.accentPrimary
                    : DesignTokens.Colors.textSecondary)
        }
        .frame(width: 26, height: 26)
    }

    // MARK: - 会话信息

    private var sessionInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected
                    ? DesignTokens.Colors.textPrimary
                    : DesignTokens.Colors.textPrimary.opacity(0.68))
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(session.username)@\(session.host)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(isSelected
                    ? DesignTokens.Colors.accentPrimary.opacity(0.52)
                    : Color.white.opacity(0.18))
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
