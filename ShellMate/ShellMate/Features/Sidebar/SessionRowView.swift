import SwiftUI

/// 会话行视图 — 1:1 对齐 Figma Make Sidebar.tsx session button
/// px-3 py-2 rounded-lg gap-2 mb-1
/// 选中：bg-[#077aff] text-white shadow-md shadow-[#077aff]/30
/// 悬停：hover:bg-black/5
struct SessionRowView: View {

    // MARK: - 属性

    let session: Session
    var isSelected: Bool = false

    // MARK: - 状态

    @State private var isHovering: Bool = false

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 0) {
            // Figma 8:16: 6×6 状态圆点，left=14，top=19（行高44居中）
            Circle()
                .fill(statusDotColor)
                .frame(width: 6, height: 6)
                .padding(.leading, 14)

            // Figma 8:17: 26×26 头像方块，left=29（dot 14 + 6 + gap 9 = 29）
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconBackground)
                Image(systemName: session.connectionType.iconName)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(iconForeground)
            }
            .frame(width: 26, height: 26)
            .padding(.leading, 9)

            // Figma 8:18/8:19: 名称+副标题，left=64（29 + 26 + gap 9 = 64）
            VStack(alignment: .leading, spacing: 1) {
                Text(session.name)
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Figma 8:19: 副标题选中白色70%，未选中 #8e8e93 = textSubtle；非标准端口追加 :port
                Text("\(session.username)@\(session.host)\(session.port != 22 ? ":\(session.port)" : "")")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(isSelected
                        ? Color.white.opacity(0.70)
                        : DesignTokens.Colors.textSubtle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.leading, 9)

            Spacer(minLength: 0)
        }
        .padding(.trailing, 10)
        // Figma: h-[44px]
        .frame(height: 44)
        .background(rowBackground)
        // 选中时蓝色阴影
        .shadow(
            color: isSelected ? DesignTokens.Colors.accentPrimary.opacity(0.30) : .clear,
            radius: 6, x: 0, y: 3
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(DesignTokens.Animation.hover, value: isSelected)
        .animation(DesignTokens.Animation.hover, value: isHovering)
        .animation(DesignTokens.Animation.medium, value: session.connectionState)
        .help("\(session.name) — \(session.username)@\(session.host)\(session.port != 22 ? ":\(session.port)" : "")")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name)，\(session.username)@\(session.host)")
        .accessibilityHint(isSelected ? "已选中，单击连接" : "单击连接此会话")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityValue(session.connectionState.displayName)
    }

    // MARK: - 背景

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            // Figma 8:15: bg-[#077aff] — 纯色蓝，不使用渐变
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary)
        } else if isHovering {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.05))
        } else {
            Color.clear
        }
    }

    // MARK: - 状态圆点颜色（Figma 8:16）

    private var statusDotColor: Color {
        switch session.connectionState {
        case .connected:    return DesignTokens.Colors.statusConnected
        case .connecting:   return DesignTokens.Colors.statusConnecting
        case .error:        return DesignTokens.Colors.statusError
        case .offline:      return Color.gray.opacity(0.35)
        case .disconnecting: return Color.gray.opacity(0.35)
        }
    }

    // MARK: - 图标颜色（状态 × 选中）

    private var iconBackground: Color {
        if isSelected { return Color.white.opacity(0.20) }
        return Color.black.opacity(0.06)
    }

    private var iconForeground: Color {
        if isSelected { return .white }
        return DesignTokens.Colors.textSecondary
    }
}


// MARK: - 预览

#Preview("会话行状态") {
    VStack(spacing: 4) {
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
    .padding(8)
    .background(DesignTokens.Colors.surfacePanel)
    .frame(width: 240)
}
