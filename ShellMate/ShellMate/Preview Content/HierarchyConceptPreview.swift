import SwiftUI

// MARK: - 方向 C 信息层级预览（概念稿，不影响生产代码）
//
// 展示两项改动：
//   1. Sidebar — 已连接会话视觉「浮出」（GlowingStatusDot + 左侧蓝色边缘线）
//   2. Toolbar — 断开改为 destructive 红字 + 按钮分组容器

// MARK: - 1. 会话行层级概念稿

private struct HierarchySessionRowConcept: View {

    let name: String
    let host: String
    let username: String
    let isConnected: Bool
    var isSelected: Bool = false

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {

            // ── 左侧连接态指示条（Direction C 新增：已连接显示 2px 蓝色边缘线）
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(isConnected
                      ? DesignTokens.Colors.accentPrimary
                      : Color.clear)
                .frame(width: 2, height: 28)
                .padding(.leading, 4)
                .padding(.trailing, 8)

            // ── 状态点：已连接用 GlowingStatusDot，离线用普通 Circle
            if isConnected {
                GlowingStatusDot(
                    color: DesignTokens.Colors.statusConnected,
                    size: 6
                )
                .frame(width: 6, height: 6)
                .padding(.trailing, 9)
            } else {
                Circle()
                    .fill(DesignTokens.Colors.textDisabled)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 9)
            }

            // ── 图标容器（与现有实现一致）
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                .fill(isSelected
                      ? Color.white.opacity(0.20)
                      : (isConnected
                         ? DesignTokens.Colors.accentPrimary.opacity(0.10)  // 已连接：淡蓝底
                         : Color.black.opacity(0.06)))
                .frame(width: 26, height: 26)
                .padding(.trailing, 9)

            // ── 会话信息
            VStack(alignment: .leading, spacing: 0) {
                // 已连接：名称字重提升为 semibold，增强辨识度
                Text(name)
                    .font(isConnected
                          ? DesignTokens.Typography.bodyMediumStrong  // 13px semibold
                          : DesignTokens.Typography.labelLarge)       // 13px medium（原有）
                    .foregroundColor(isSelected
                                     ? .white
                                     : (isConnected
                                        ? DesignTokens.Colors.textPrimary
                                        : DesignTokens.Colors.textSecondary))  // 离线略淡
                    .lineLimit(1)

                Text("\(username)@\(host)")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(isSelected
                                     ? Color.white.opacity(0.70)
                                     : DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 44)
        .padding(.trailing, 12)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

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
}

// MARK: - 2. 工具栏层级概念稿

private struct HierarchyToolbarConcept: View {

    var body: some View {
        HStack(spacing: 4) {

            // ── 分组 1：连接管理（主操作 + 析构操作）──
            HStack(spacing: 4) {
                // 连接：tinted 蓝（已有）
                conceptButton("⏻ 连接", tone: .tinted)
                // 断开：destructive 红字（Direction C 新增）
                conceptButton("断开", tone: .destructive)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )

            // ── 分割线 ──
            divider

            // ── 分组 2：功能工具（中性操作）──
            HStack(spacing: 4) {
                conceptButton("✦ AI", tone: .normal)
                conceptButton("</> 脚本", tone: .normal)
                conceptButton("⇅ 文件", tone: .normal)
                conceptButton("⊡ 分屏", tone: .normal)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )

            // ── 溢出 ──
            conceptButton("··· 更多", tone: .normal)

            Spacer()

            // ── 右侧图标区 ──
            divider
            Image(systemName: "shippingbox")
                .toolbarIconStyle()
            Image(systemName: "magnifyingglass")
                .toolbarIconStyle()
            Image(systemName: "record.circle")
                .toolbarIconStyle()
            divider
            Image(systemName: "gearshape")
                .toolbarIconStyle()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(DesignTokens.Colors.surfaceWindow)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    private func conceptButton(_ label: String, tone: ConceptTone) -> some View {
        Text(verbatim: label)
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(tone.foreground)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tone.background)
            )
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.borderPrimary)
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }
}

// MARK: - Tone 辅助

private enum ConceptTone {
    case tinted, normal, destructive

    var foreground: Color {
        switch self {
        case .tinted:      return DesignTokens.Colors.accentPrimary
        case .normal:      return DesignTokens.Colors.textSecondary
        case .destructive: return Color(hex: "#ff3b30")
        }
    }

    var background: Color {
        switch self {
        case .tinted:      return DesignTokens.Colors.accentPrimary.opacity(0.08)
        case .normal:      return Color.black.opacity(0.07)
        case .destructive: return Color(hex: "#ff3b30").opacity(0.08)
        }
    }
}

private extension View {
    func toolbarIconStyle() -> some View {
        self.font(.system(size: 15, weight: .regular))
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.07))
            )
    }
}

// MARK: - 完整侧边栏概念稿

private struct HierarchySidebarConcept: View {
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Text("Sessions")
                    .font(DesignTokens.Typography.bodyLargeMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5)
            }

            // 会话列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    // 已连接（选中态）
                    HierarchySessionRowConcept(
                        name: "Production Server",
                        host: "192.168.1.10",
                        username: "ubuntu",
                        isConnected: true,
                        isSelected: true
                    )

                    // 已连接（未选中）
                    HierarchySessionRowConcept(
                        name: "Dev Server",
                        host: "192.168.1.20",
                        username: "ubuntu",
                        isConnected: true
                    )

                    // 离线
                    HierarchySessionRowConcept(
                        name: "Staging",
                        host: "192.168.1.30",
                        username: "ubuntu",
                        isConnected: false
                    )

                    // 离线
                    HierarchySessionRowConcept(
                        name: "Backup DB",
                        host: "192.168.1.40",
                        username: "admin",
                        isConnected: false
                    )
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }

            Spacer()

            // Footer
            HStack {
                Text("2 connected")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Text("4 total")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(DesignTokens.Colors.surfaceWindow)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5)
            }
        }
        .frame(width: 256)
        .background(DesignTokens.Colors.surfaceWindow)
    }
}

// MARK: - 预览：对比当前 vs 方向 C

#Preview("方向 C — 侧边栏信息层级（左：现有 / 右：方向 C）") {
    HStack(spacing: 0) {
        // 左：现有实现
        VStack(spacing: 0) {
            Text("现有")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.06))

            VStack(spacing: 4) {
                SessionRowView(session: {
                    var s = Session.preview
                    s.connectionState = .connected
                    s.name = "Production Server"
                    s.host = "192.168.1.10"
                    return s
                }(), isSelected: true)

                SessionRowView(session: {
                    var s = Session.preview
                    s.connectionState = .connected
                    s.name = "Dev Server"
                    s.host = "192.168.1.20"
                    return s
                }())

                SessionRowView(session: {
                    var s = Session.preview
                    s.connectionState = .offline
                    s.name = "Staging"
                    s.host = "192.168.1.30"
                    return s
                }())

                SessionRowView(session: {
                    var s = Session.preview
                    s.connectionState = .offline
                    s.name = "Backup DB"
                    s.host = "192.168.1.40"
                    return s
                }())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)

            Spacer()
        }
        .frame(width: 256)
        .background(DesignTokens.Colors.surfaceWindow)

        Divider()

        // 右：方向 C 概念稿
        VStack(spacing: 0) {
            Text("方向 C")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(DesignTokens.Colors.accentPrimary.opacity(0.08))

            VStack(spacing: 4) {
                HierarchySessionRowConcept(
                    name: "Production Server",
                    host: "192.168.1.10",
                    username: "ubuntu",
                    isConnected: true,
                    isSelected: true
                )
                HierarchySessionRowConcept(
                    name: "Dev Server",
                    host: "192.168.1.20",
                    username: "ubuntu",
                    isConnected: true
                )
                HierarchySessionRowConcept(
                    name: "Staging",
                    host: "192.168.1.30",
                    username: "ubuntu",
                    isConnected: false
                )
                HierarchySessionRowConcept(
                    name: "Backup DB",
                    host: "192.168.1.40",
                    username: "admin",
                    isConnected: false
                )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)

            Spacer()
        }
        .frame(width: 256)
        .background(DesignTokens.Colors.surfaceWindow)
    }
    .frame(height: 320)
}

#Preview("方向 C — 工具栏信息层级（上：现有 / 下：方向 C）") {
    VStack(spacing: 0) {
        // 上：现有工具栏（用真实组件模拟）
        VStack(spacing: 0) {
            Text("现有")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            HStack(spacing: 4) {
                Group {
                    Text(verbatim: "⏻ 连接")
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                        .background(Capsule().fill(DesignTokens.Colors.accentPrimary.opacity(0.08)))
                    Text(verbatim: "断开")
                    Rectangle().fill(DesignTokens.Colors.borderPrimary).frame(width: 1, height: 20)
                    Text(verbatim: "✦ AI")
                    Text(verbatim: "</> 脚本")
                    Text(verbatim: "⇅ 文件")
                    Text(verbatim: "⊡ 分屏")
                    Text(verbatim: "··· 更多")
                }
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.07)))
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(DesignTokens.Colors.surfaceWindow)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5)
            }
        }

        Divider().padding(.vertical, 8)

        // 下：方向 C 工具栏概念稿
        VStack(spacing: 0) {
            Text("方向 C")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            HierarchyToolbarConcept()
        }
    }
    .frame(width: 900)
    .background(DesignTokens.Colors.surfaceWindow)
}
