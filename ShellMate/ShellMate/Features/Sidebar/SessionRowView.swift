import SwiftUI

/// 会话行视图 — 1:1 对齐 Figma Make Sidebar.tsx session button
/// px-3 py-2 rounded-lg gap-2 mb-1
/// 选中：bg-[#007aff] text-white shadow-md shadow-[#007aff]/30
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
            // 图标容器：背景色随连接状态变化，兼顾状态指示与类型展示，去掉独立状态圆点
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconBackground)
                Image(systemName: session.connectionType.iconName)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(iconForeground)
            }
            .frame(width: 26, height: 26)
            .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.name)
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Figma 8:24: 副标题选中白色70%，未选中 #8e8e93 = textSubtle；非标准端口追加 :port
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
        .overlay(alignment: .leading) { statusBar }
        // 选中时渐变阴影，比单色更有深度感
        .shadow(
            color: isSelected ? DesignTokens.Colors.accentPrimary.opacity(0.30) : .clear,
            radius: 6, x: 0, y: 3
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(DesignTokens.Animation.hover, value: isSelected)
        .animation(DesignTokens.Animation.hover, value: isHovering)
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else if isHovering {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.05))
        } else {
            Color.clear
        }
    }

    // MARK: - 左侧状态竖条

    private var statusBarColor: Color? {
        if isSelected { return Color.white.opacity(0.75) }
        switch session.connectionState {
        case .connected:    return DesignTokens.Colors.statusConnected
        case .connecting:   return DesignTokens.Colors.statusConnecting
        case .error:        return DesignTokens.Colors.statusError
        default:            return nil
        }
    }

    @ViewBuilder
    private var statusBar: some View {
        if let color = statusBarColor {
            Capsule()
                .fill(color)
                .frame(width: 2, height: 20)
                .padding(.leading, 4)
        }
    }

    // MARK: - 图标颜色（状态 × 选中）

    private var iconBackground: Color {
        if isSelected { return Color.white.opacity(0.20) }
        switch session.connectionState {
        case .connected:   return DesignTokens.Colors.statusConnected.opacity(0.15)
        case .connecting:  return DesignTokens.Colors.statusConnecting.opacity(0.15)
        case .error:       return DesignTokens.Colors.statusError.opacity(0.12)
        case .offline:     return Color.black.opacity(0.06)
        case .disconnecting: return Color.black.opacity(0.06)
        }
    }

    private var iconForeground: Color {
        if isSelected { return .white }
        switch session.connectionState {
        case .connected:   return DesignTokens.Colors.statusConnected
        case .connecting:  return DesignTokens.Colors.statusConnecting
        case .error:       return DesignTokens.Colors.statusError
        case .offline:     return DesignTokens.Colors.textSecondary
        case .disconnecting: return DesignTokens.Colors.textSecondary
        }
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
