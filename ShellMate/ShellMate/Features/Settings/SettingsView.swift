import SwiftUI

// MARK: - 设置面板主窗口（对齐 Figma Desktop 设计，600×580pt，3 Tab）

/// 设置窗口主容器
/// 顶部文本 Tab 栏（通用 / 外观 / 终端），共 600×580pt
/// Tab 栏：bg=rgba(0,0,0,0.02)，h=44，左侧 padding=16；每个 Tab width=72，height=32，cornerRadius=8
struct SettingsView: View {

    // MARK: - 关闭回调（自定义浮动面板模式）
    var onClose: (() -> Void)? = nil

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
    @Namespace private var settingsTabNamespace

    // Phase 6：设置搜索（解 UE-P1#13）
    @State private var searchText: String = ""
    @State private var showSearchResults: Bool = false
    @FocusState private var searchFocused: Bool

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // Figma 14:3 — "设置" 标题 text-[18px] font-semibold text-[#1d1d1f] left-[28px] top-[24px] h=56
            titleHeaderView
            // Tab 选择器（h=44，bg-[rgba(0,0,0,0.02)]）
            tabPickerBar
            // Figma 14:11 — bg-[rgba(0,0,0,0.08)] h-[0.5px]
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
            // 内容区域
            contentPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Figma 14:51 — bottom divider
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
            // Figma 14:52 — 保存按钮
            saveButtonRow
        }
        .frame(width: 600, height: 584)
        // Figma Desktop: #fafafb 背景
        .background(DesignTokens.Colors.surfaceWindow)
    }

    // Figma 14:3: text-[18px] font-semibold text-[#1d1d1f], h=56；右侧关闭按钮（自定义浮动面板模式）
    private var titleHeaderView: some View {
        HStack {
            Text("设置")
                .font(DesignTokens.Typography.titlePanel)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Spacer()
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textSubtle)
                        .frame(width: 24, height: 24)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 56)
    }

    // Figma 14:52: bg-[#077aff] h-[36px] w-[80px] rounded-[8px] shadow-[0px_4px_12px_0px_rgba(7,122,255,0.3)]
    private var saveButtonRow: some View {
        HStack {
            Spacer()
            Button("保存") {}
                .font(DesignTokens.Typography.bodyLargeMedium)
                .foregroundColor(.white)
                .frame(width: 80, height: 36)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 6, x: 0, y: 4)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .frame(height: 47)
    }

    // MARK: - 顶部选择器（Figma Desktop 规格）

    private var tabPickerBar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { selectedTab = tab }
                } label: {
                    Text(verbatim: tab.rawValue)
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(selectedTab == tab ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSubtle)
                        .frame(width: 72, height: 32)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(DesignTokens.Colors.surfaceActive)
                                    .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "settingsTabBG", in: settingsTabNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .background(Color.black.opacity(0.02))
        .overlay(alignment: .trailing) {
            // Phase 6：搜索框置于 Tab 栏右侧
            settingsSearchField
                .padding(.trailing, 12)
        }
    }

    // MARK: - Phase 6：设置搜索 UI

    @ViewBuilder
    private var settingsSearchField: some View {
        HStack(spacing: 4) {
            AppIcon.search.image
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            TextField("搜索设置…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($searchFocused)
                .frame(width: 120)
                .onChange(of: searchText) { newValue in
                    showSearchResults = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                }
            if !searchText.isEmpty {
                Button(action: { searchText = ""; showSearchResults = false }) {
                    AppIcon.dismiss.image
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(searchFocused ? DesignTokens.Colors.accentPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if showSearchResults {
                settingsSearchResultsPopover
                    .frame(width: 280)
                    .offset(x: 0, y: 30)
            }
        }
    }

    @ViewBuilder
    private var settingsSearchResultsPopover: some View {
        let results = SettingsIndex.shared.search(searchText)
        VStack(alignment: .leading, spacing: 0) {
            if results.isEmpty {
                Text("无匹配设置项")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ForEach(results.prefix(8)) { item in
                    Button(action: { jumpToSearchResult(item) }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Text("\(tabDisplayName(item.tab)) · \(item.section)")
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private func tabDisplayName(_ indexTab: ShellMate.SettingsTab) -> String {
        // SettingsIndex.SettingsTab 名称翻译（与 SettingsView.SettingsTab 部分重叠）
        switch indexTab.rawValue {
        case "general":    return "通用"
        case "appearance": return "外观"
        case "terminal":   return "终端"
        case "ai":         return "AI 助手"
        case "automation": return "自动化"
        case "highlight":  return "关键词高亮"
        case "security":   return "安全"
        case "icloud":     return "iCloud 同步"
        default:           return indexTab.rawValue
        }
    }

    private func jumpToSearchResult(_ item: SettingItem) {
        // 尝试映射到本 View 仅有的 3 个 Tab（general/appearance/terminal）
        switch item.tab.rawValue {
        case "general":    selectedTab = .general
        case "appearance": selectedTab = .appearance
        case "terminal":   selectedTab = .terminal
        default:
            // 当前 View 不支持的 tab（ai/security/icloud 等）— 给出 Toast 提示
            FeedbackCenter.shared.present(.info(
                "该设置项在独立面板",
                message: "请前往该模块的独立设置入口"
            ))
        }
        searchText = ""
        showSearchResults = false
    }

    // MARK: - 内容区（3 Tab 合并策略）

    @ViewBuilder
    private var contentPanel: some View {
        switch selectedTab {
        case .general:
            // Figma 14:2 通用 Tab：仅显示 GeneralSettingsView（连接/通知/安全三分区）
            ScrollView {
                generalContent
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
