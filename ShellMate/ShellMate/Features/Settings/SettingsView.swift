import SwiftUI

// MARK: - 设置面板主窗口（Screen 07）

/// 设置窗口主容器
/// 左侧导航 160pt + 右侧内容 480pt，共 640×520pt，不可调整大小
struct SettingsView: View {

    // MARK: - 导航项

    enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "外观"
        case highlight  = "关键词高亮"
        case security   = "安全"
        case terminal   = "终端"
        case cloudSync  = "iCloud 同步"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .appearance: return "paintbrush.fill"
            case .highlight:  return "highlighter"
            case .security:   return "lock.shield.fill"
            case .terminal:   return "terminal.fill"
            case .cloudSync:  return "icloud.fill"
            }
        }
    }

    // MARK: - 状态

    @State private var selectedTab: SettingsTab = .appearance

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航 (160pt)
            navPanel

            Divider()

            // 右侧内容 (480pt)
            contentPanel
                .frame(width: 480)
        }
        .frame(width: 640, height: 520)
    }

    // MARK: - 左侧导航栏

    private var navPanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                navItem(tab)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .frame(width: 160)
        .background(
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
        )
    }

    private func navItem(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab

        return Button(action: { selectedTab = tab }) {
            HStack(spacing: 8) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 14))
                    .frame(width: 16, alignment: .center)

                Text(tab.rawValue)
                    .font(.system(size: 12))

                Spacer()
            }
            .foregroundColor(isSelected
                ? DesignTokens.Colors.textPrimary
                : DesignTokens.Colors.textSecondary)
            .padding(.vertical, 6)
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
            )
            .overlay(
                // 左侧 2pt 指示线
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 2),
                alignment: .leading
            )
            .cornerRadius(4, corners: [.topRight, .bottomRight])
        }
        .buttonStyle(.plain)
    }

    // MARK: - 右侧内容区

    @ViewBuilder
    private var contentPanel: some View {
        Group {
            switch selectedTab {
            case .appearance:
                AppearanceSettingsView()
            case .highlight:
                HighlightSettingsView()
            case .security:
                SecuritySettingsView()
            case .terminal:
                TerminalSettingsView()
            case .cloudSync:
                CloudSyncSettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
