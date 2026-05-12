import SwiftUI

// MARK: - 设置面板主窗口（对齐 Figma Desktop 设计，600×580pt，3 Tab）

/// 设置窗口主容器
/// 顶部文本 Tab 栏（通用 / 外观 / 终端），共 600×580pt
/// Tab 栏：bg=rgba(0,0,0,0.02)，h=44，左侧 padding=16；每个 Tab width=72，height=32，cornerRadius=8
struct SettingsView: View {

    // MARK: - 导航项（3 个 Tab：通用 / 外观 / 终端）

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general    = "通用"
        case appearance = "外观"
        case terminal   = "终端"

        var id: String { rawValue }
        var localizedLabel: LocalizedStringKey { LocalizedStringKey(rawValue) }
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
        .frame(width: 600, height: 580)
        // Figma Desktop: #fafafb 背景，rounded-16px，shadow
        .background(Color(hex: "#fafafb"))
    }

    // MARK: - 顶部选择器（Figma Desktop 规格）

    private var tabPickerBar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                } label: {
                    Text(tab.localizedLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectedTab == tab ? Color(hex: "#1d1d1f") : Color(hex: "#8e8e93"))
                        .frame(width: 72, height: 32)
                        .background(selectedTab == tab ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: selectedTab == tab ? Color.black.opacity(0.06) : .clear,
                                radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .background(Color.black.opacity(0.02))
    }

    // MARK: - 内容区（3 Tab 合并策略）

    @ViewBuilder
    private var contentPanel: some View {
        switch selectedTab {
        case .general:
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    generalContent
                    Divider().padding(.horizontal, 20).padding(.vertical, 4)
                    aiContent
                    Divider().padding(.horizontal, 20).padding(.vertical, 4)
                    automationContent
                }
            }
        case .appearance:
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    appearanceContent
                    Divider().padding(.horizontal, 20).padding(.vertical, 4)
                    colorsContent
                }
            }
        case .terminal:
            TerminalSettingsView()
        }
    }

    // MARK: - 内容属性

    private var generalContent: some View    { GeneralSettingsView().settingsContent }
    private var aiContent: some View         { AISettingsView().settingsContent }
    private var automationContent: some View { AutomationTriggersSettingsView() }
    private var appearanceContent: some View { AppearanceSettingsView().settingsContent }
    private var colorsContent: some View     { ColorsSettingsView().settingsContent }
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
