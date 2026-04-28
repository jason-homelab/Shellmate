import SwiftUI

// MARK: - 设置面板主窗口（Screen 07 — Figma-Spec-v2 §07，2026-04-27 更新至 6 Tab）

/// 设置窗口主容器
/// 顶部 Segmented Picker（通用/外观/终端/颜色/AI助手/自动化），共 640×520pt
/// 对齐 Figma-Spec-v2 §07：grid-cols-6，bg-black/5，backdrop-blur-sm，rounded-xl，p-1
struct SettingsView: View {

    // MARK: - 导航项（六主 Tab，W26 新增自动化 Tab）

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general     = "通用"
        case appearance  = "外观"
        case terminal    = "终端"
        case colors      = "颜色"
        case aiAssistant = "AI 助手"
        case automation  = "自动化"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .general:     return "gearshape"
            case .appearance:  return "paintpalette"
            case .terminal:    return "terminal"
            case .colors:      return "circle.hexagongrid.fill"
            case .aiAssistant: return "sparkles"
            case .automation:  return "bolt"
            }
        }
    }

    // MARK: - 状态

    @State private var selectedTab: SettingsTab = .general

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 Tab 选择器（5 格等宽，对齐 Figma grid-cols-5）
            tabPickerBar

            Divider()

            // 内容区域
            contentPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 600, height: 520)
        // Figma: bg-white/95 backdrop-blur-2xl
        .background {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color.white.opacity(0.95))
        }
    }

    // MARK: - 顶部选择器

    private var tabPickerBar: some View {
        HStack(spacing: DesignTokens.Spacing.xxxs) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: tab.iconName)
                            .font(DesignTokens.Typography.captionLarge)
                        // Figma: text-xs = 11pt
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .medium : .regular))
                    }
                    // Figma: active=text-primary, inactive=text-secondary, text-xs
                    .foregroundColor(
                        selectedTab == tab
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    // Figma: active=bg-white shadow-sm, inactive=transparent
                    .background(
                        selectedTab == tab
                            ? Color.white
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .shadow(color: selectedTab == tab ? Color.black.opacity(0.08) : Color.clear, radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.xxs)
        // Figma: bg-black/5 backdrop-blur-sm rounded-xl p-1（无边框）
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentPanel: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .terminal:
            TerminalSettingsView()
        case .colors:
            ColorsSettingsView()
        case .aiAssistant:
            AISettingsView()
        case .automation:
            AutomationTriggersSettingsView()
        }
    }
}

// MARK: - Vibrancy 效果包装（NSVisualEffectView）

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - 圆角辅助扩展

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    static let topLeft     = RectCorner(rawValue: 1 << 0)
    static let topRight    = RectCorner(rawValue: 1 << 1)
    static let bottomLeft  = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let all: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: RectCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = corners.contains(.topLeft)     ? radius : 0
        let tr = corners.contains(.topRight)    ? radius : 0
        let bl = corners.contains(.bottomLeft)  ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                    radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                    radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                    radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                    radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - 预览

#Preview("设置面板") {
    SettingsView()
}
