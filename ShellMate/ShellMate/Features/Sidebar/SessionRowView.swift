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
            // Figma 8:16/8:21: 状态点 6×6，left=14 within row（行左边距4 + 点14 = 18px from sidebar）
            // 所有状态均显示点：连接=绿，离线=灰，连接中=黄，错误=红
            Circle()
                .fill(session.connectionState.dotColor)
                .frame(width: 6, height: 6)
                .padding(.leading, 14)

            // Figma 8:17/8:22: 图标容器 26×26 rounded-6，left=29 within row（dot 14 + 6 + 9 = 29）
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected
                        ? Color.white.opacity(0.20)
                        : Color.black.opacity(0.06))
                Image(systemName: session.connectionType.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)
            }
            .frame(width: 26, height: 26)
            .padding(.leading, 9)

            // Figma 8:18/8:23+24: 名称 13px medium + 子标题 11px，left=64 within row
            VStack(alignment: .leading, spacing: 1) {
                Text(session.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Figma 8:24: 副标题选中白色70%，未选中 #8e8e93 = textSubtle
                Text("\(session.username)@\(session.host)")
                    .font(.system(size: 11))
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
        // shadow-md shadow-[#007aff]/30（仅选中时）
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
                .fill(DesignTokens.Colors.accentPrimary)
        } else if isHovering {
            // hover:bg-black/5
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.05))
        } else {
            Color.clear
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
