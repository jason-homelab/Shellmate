import SwiftUI
import AppKit

// MARK: - 终端主题定义

/// 内置终端颜色主题
struct AppTheme: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    /// 背景色十六进制字符串
    let backgroundHex: String
    /// 提示符色十六进制字符串
    let promptHex: String
    /// 输出文字色十六进制字符串
    let outputHex: String
    /// 16 色 ANSI 调色板（十六进制字符串，索引 0-15）
    let ansiColors: [String]

    var background: Color  { Color(hex: backgroundHex) }
    var promptColor: Color { Color(hex: promptHex) }
    var outputColor: Color { Color(hex: outputHex) }

    // MARK: - 内置主题

    static let builtins: [AppTheme] = [
        AppTheme(id: "shellmate-dark",  name: "ShellMate Dark",
                 backgroundHex: "#0C0C0E", promptHex: "#4CAF7D", outputHex: "#8E8E9A",
                 ansiColors: ["#1C1C1E","#FF453A","#4CAF7D","#FFD60A","#0A84FF","#BF5AF2","#5AC8FA","#8E8E9A",
                              "#3A3A3C","#FF6961","#6FD19B","#FFE55C","#409CFF","#DA8FFF","#7DD4F8","#FFFFFF"]),
        AppTheme(id: "shellmate-light", name: "ShellMate Light",
                 backgroundHex: "#FFFFFF", promptHex: "#1E8C52", outputHex: "#6B6B7B",
                 ansiColors: ["#000000","#C0392B","#1E8C52","#B7950B","#2980B9","#8E44AD","#16A085","#7F8C8D",
                              "#6B6B7B","#E74C3C","#27AE60","#F1C40F","#3498DB","#9B59B6","#1ABC9C","#ECF0F1"]),
        AppTheme(id: "solarized-dark",  name: "Solarized Dark",
                 backgroundHex: "#002B36", promptHex: "#859900", outputHex: "#657B83",
                 ansiColors: ["#073642","#DC322F","#859900","#B58900","#268BD2","#D33682","#2AA198","#EEE8D5",
                              "#002B36","#CB4B16","#586E75","#657B83","#839496","#6C71C4","#93A1A1","#FDF6E3"]),
        AppTheme(id: "solarized-light", name: "Solarized Light",
                 backgroundHex: "#FDF6E3", promptHex: "#657B83", outputHex: "#93A1A1",
                 ansiColors: ["#EEE8D5","#DC322F","#859900","#B58900","#268BD2","#D33682","#2AA198","#073642",
                              "#FDF6E3","#CB4B16","#586E75","#657B83","#839496","#6C71C4","#93A1A1","#002B36"]),
        AppTheme(id: "dracula",         name: "Dracula",
                 backgroundHex: "#282A36", promptHex: "#BD93F9", outputHex: "#6272A4",
                 ansiColors: ["#21222C","#FF5555","#50FA7B","#F1FA8C","#BD93F9","#FF79C6","#8BE9FD","#F8F8F2",
                              "#6272A4","#FF6E6E","#69FF94","#FFFFA5","#D6ACFF","#FF92DF","#A4FFFF","#FFFFFF"]),
        AppTheme(id: "one-dark",        name: "One Dark",
                 backgroundHex: "#282C34", promptHex: "#98C379", outputHex: "#5C6370",
                 ansiColors: ["#282C34","#E06C75","#98C379","#E5C07B","#61AFEF","#C678DD","#56B6C2","#ABB2BF",
                              "#5C6370","#E06C75","#98C379","#E5C07B","#61AFEF","#C678DD","#56B6C2","#FFFFFF"]),
        AppTheme(id: "nord",            name: "Nord",
                 backgroundHex: "#2E3440", promptHex: "#88C0D0", outputHex: "#4C566A",
                 ansiColors: ["#2E3440","#BF616A","#A3BE8C","#EBCB8B","#81A1C1","#B48EAD","#88C0D0","#E5E9F0",
                              "#4C566A","#BF616A","#A3BE8C","#EBCB8B","#81A1C1","#B48EAD","#8FBCBB","#ECEFF4"]),
        AppTheme(id: "gruvbox",         name: "Gruvbox",
                 backgroundHex: "#282828", promptHex: "#B8BB26", outputHex: "#928374",
                 ansiColors: ["#282828","#CC241D","#98971A","#D79921","#458588","#B16286","#689D6A","#A89984",
                              "#928374","#FB4934","#B8BB26","#FABD2F","#83A598","#D3869B","#8EC07C","#EBDBB2"])
    ]

    // MARK: - 用户自定义主题

    private static let customThemesKey = "appearance.customThemes"

    /// 所有可用主题（内置 + 用户导入）
    static var allThemes: [AppTheme] {
        var themes = builtins
        if let data = UserDefaults.standard.data(forKey: customThemesKey),
           let custom = try? JSONDecoder().decode([AppTheme].self, from: data) {
            themes.append(contentsOf: custom)
        }
        return themes
    }

    /// 保存用户自定义主题
    static func saveCustomTheme(_ theme: AppTheme) {
        var existing = loadCustomThemes()
        existing.removeAll { $0.id == theme.id }
        existing.append(theme)
        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: customThemesKey)
        }
    }

    private static func loadCustomThemes() -> [AppTheme] {
        guard let data = UserDefaults.standard.data(forKey: customThemesKey),
              let custom = try? JSONDecoder().decode([AppTheme].self, from: data) else { return [] }
        return custom
    }
}

// MARK: - 光标形状

/// 终端光标形状选项
enum CursorShape: String, CaseIterable {
    case block     = "block"
    case iBeam     = "iBeam"
    case underline = "underline"

    var displayName: String {
        switch self {
        case .block:     return "块状"
        case .iBeam:     return "竖线"
        case .underline: return "下划线"
        }
    }

    var iconAspect: (width: CGFloat, height: CGFloat) {
        switch self {
        case .block:     return (7, 14)
        case .iBeam:     return (2, 14)
        case .underline: return (7, 2)
        }
    }
}

// MARK: - 外观设置视图

/// S02 — 外观与个性化设置面板
struct AppearanceSettingsView: View {

    // MARK: - 持久化设置 (@AppStorage)

    @AppStorage("appearance.themeId")         private var selectedThemeId: String = "shellmate-dark"
    /// 当前可用主题列表（内置 + 用户导入），导入后刷新
    @State private var availableThemes: [AppTheme] = AppTheme.allThemes
    /// 是否显示自定义主题编辑器
    @State private var showCustomThemeEditor: Bool = false
    @AppStorage("appearance.fontFamily")      private var fontFamily: String = "JetBrains Mono"
    @AppStorage("appearance.fontSize")        private var fontSize: Double = 13
    @AppStorage("appearance.lineSpacing")     private var lineSpacing: Double = 1.4
    @AppStorage("appearance.ligatures")       private var ligatures: Bool = false
    @AppStorage("appearance.nonAsciiFontFamily") private var nonAsciiFont: String = "冬青黑体"
    @AppStorage("appearance.cursorShape")     private var cursorShapeRaw: String = CursorShape.block.rawValue
    @AppStorage("appearance.cursorBlink")     private var cursorBlink: Bool = true
    @AppStorage("appearance.cursorBlinkIdleOnly") private var cursorBlinkIdleOnly: Bool = false
    @AppStorage("appearance.bgOpacity")       private var bgOpacity: Double = 0

    /// 当前光标形状
    private var cursorShape: CursorShape {
        CursorShape(rawValue: cursorShapeRaw) ?? .block
    }

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // S02-B：颜色主题
                themeSectionView

                Divider().padding(.vertical, 20)

                // S02-C：字体配置
                fontSectionView

                Divider().padding(.vertical, 20)

                // S02-E：光标配置
                cursorSectionView

                Divider().padding(.vertical, 20)

                // S02-F：窗口配置
                windowSectionView

                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - 颜色主题 Section

    private var themeSectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("颜色主题")

            // 主题卡片网格（自适应列宽，保证间距足够）
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 80, maximum: 96), spacing: DesignTokens.Spacing.md), count: 5),
                spacing: DesignTokens.Spacing.md
            ) {
                ForEach(availableThemes) { theme in
                    ThemeCardView(
                        theme: theme,
                        isSelected: selectedThemeId == theme.id
                    ) {
                        selectedThemeId = theme.id
                    }
                }
                customThemeCard
            }
            .padding(.top, 14)

            // 辅助按钮
            HStack(spacing: 10) {
                Button(action: importItermColors) {
                    Label("导入 .itermcolors", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: exportCurrentTheme) {
                    Label("导出主题", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 14)
        }
        .sheet(isPresented: $showCustomThemeEditor) {
            CustomThemeEditorSheet(
                onSave: { theme in
                    AppTheme.saveCustomTheme(theme)
                    availableThemes = AppTheme.allThemes
                    selectedThemeId = theme.id
                    showCustomThemeEditor = false
                },
                onCancel: {
                    showCustomThemeEditor = false
                }
            )
            .frame(width: 400, height: 480)
        }
    }

    /// 自定义主题占位卡（点击打开编辑器）
    private var customThemeCard: some View {
        Button(action: { showCustomThemeEditor = true }) {
            VStack(spacing: 0) {
                ZStack {
                    DesignTokens.Colors.surfaceCard
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)

                Text("自定义")
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .background(DesignTokens.Colors.surfacePanel)
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .help("创建自定义颜色主题")
    }

    // MARK: - 字体配置 Section

    private var fontSectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("字体")

            VStack(alignment: .leading, spacing: 14) {
                fontFamilyRow
                fontSizeRow
                lineSpacingRow

                // 连字（Toggle + 说明分两行）
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("启用字体连字（Ligatures）")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Spacer()
                        Toggle("", isOn: $ligatures)
                            .toggleStyle(.switch).labelsHidden()
                    }

                    Text("⚠ 需字体支持（Fira Code, JetBrains Mono）")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }

                nonAsciiRow

                // 实时预览
                fontPreviewArea
            }
            .padding(.top, 14)
        }
    }

    // MARK: - 主题导入/导出

    /// 导入 .itermcolors 主题文件
    private func importItermColors() {
        let panel = NSOpenPanel()
        panel.title = "选择 .itermcolors 主题文件"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK,
                  let url = panel.url,
                  url.pathExtension.lowercased() == "itermcolors" else { return }
            guard let theme = parseItermColors(url: url) else { return }
            AppTheme.saveCustomTheme(theme)
            DispatchQueue.main.async {
                availableThemes = AppTheme.allThemes
                selectedThemeId = theme.id
            }
        }
    }

    /// 解析 .itermcolors 文件为 AppTheme
    private func parseItermColors(url: URL) -> AppTheme? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        func hexFromDict(_ dict: [String: Any]?) -> String {
            guard let d = dict else { return "#000000" }
            let r = d["Red Component"] as? Double ?? 0
            let g = d["Green Component"] as? Double ?? 0
            let b = d["Blue Component"] as? Double ?? 0
            return String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        }

        var ansi: [String] = []
        for i in 0...15 {
            ansi.append(hexFromDict(plist["Ansi \(i) Color"] as? [String: Any]))
        }

        let bgHex = hexFromDict(plist["Background Color"] as? [String: Any])
        let fgHex = hexFromDict(plist["Foreground Color"] as? [String: Any])
        let promptHex = ansi.count > 2 ? ansi[2] : fgHex

        let rawName = url.deletingPathExtension().lastPathComponent
        let themeId = "custom-\(rawName.lowercased().replacingOccurrences(of: " ", with: "-"))"
        return AppTheme(id: themeId, name: rawName, backgroundHex: bgHex, promptHex: promptHex, outputHex: fgHex, ansiColors: ansi)
    }

    /// 将当前选中主题导出为 .itermcolors 文件
    private func exportCurrentTheme() {
        guard let theme = availableThemes.first(where: { $0.id == selectedThemeId }) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(theme.name).itermcolors"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let data = buildItermColors(from: theme)
            try? data.write(to: url)
        }
    }

    /// 将 AppTheme 序列化为 .itermcolors XML 数据
    private func buildItermColors(from theme: AppTheme) -> Data {
        func componentDict(hex: String) -> [String: Any] {
            let stripped = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: stripped).scanHexInt64(&int)
            return [
                "Red Component":   Double((int >> 16) & 0xFF) / 255.0,
                "Green Component": Double((int >> 8)  & 0xFF) / 255.0,
                "Blue Component":  Double(int         & 0xFF) / 255.0,
                "Alpha Component": 1.0,
                "Color Space": "sRGB"
            ]
        }
        var dict: [String: Any] = [:]
        for (i, hex) in theme.ansiColors.prefix(16).enumerated() {
            dict["Ansi \(i) Color"] = componentDict(hex: hex)
        }
        dict["Background Color"] = componentDict(hex: theme.backgroundHex)
        dict["Foreground Color"] = componentDict(hex: theme.outputHex)
        return (try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)) ?? Data()
    }

    // MARK: - Section 标题辅助

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(DesignTokens.Colors.textPrimary)
    }

    // MARK: - 表单行辅助（统一 label 宽度 = 88pt）

    private var fontFamilyRow: some View {
        HStack(spacing: 12) {
            rowLabel("字体族")
            Picker("", selection: $fontFamily) {
                Text("JetBrains Mono").tag("JetBrains Mono")
                Text("Fira Code").tag("Fira Code")
                Text("Menlo").tag("Menlo")
                Text("Monaco").tag("Monaco")
                Text("SF Mono").tag("SF Mono")
                Text("Courier New").tag("Courier New")
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }

    private var fontSizeRow: some View {
        HStack(spacing: 12) {
            rowLabel("字号")
            Slider(value: $fontSize, in: 8...32, step: 1)
                .accentColor(DesignTokens.Colors.accentPrimary)
            Text("\(Int(fontSize)) pt")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 42, alignment: .trailing)
            HStack(spacing: 0) {
                Button(action: { fontSize = max(8, fontSize - 1) }) {
                    Image(systemName: "minus").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                Button(action: { fontSize = min(32, fontSize + 1) }) {
                    Image(systemName: "plus").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
            }
        }
    }

    private var lineSpacingRow: some View {
        HStack(spacing: 12) {
            rowLabel("行间距")
            Slider(value: $lineSpacing, in: 0.8...2.0, step: 0.1)
                .accentColor(DesignTokens.Colors.accentPrimary)
            Text(String(format: "%.1f×", lineSpacing))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private var nonAsciiRow: some View {
        HStack(spacing: 12) {
            rowLabel("非 ASCII 字体")
            Picker("", selection: $nonAsciiFont) {
                Text("冬青黑体").tag("冬青黑体")
                Text("华文细黑").tag("华文细黑")
                Text("苹方").tag("苹方")
                Text("PingFang SC").tag("PingFang SC")
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            Text("中文等宽字符")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    private func rowLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .frame(width: 88, alignment: .leading)
    }

    private var fontPreviewArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text("ubuntu@server:~$ ")
                    .foregroundColor(DesignTokens.Colors.terminalPromptDefault)
                Text("ls -la")
                    .foregroundColor(.white)
            }
            .font(.custom(fontFamily, size: fontSize))

            Text("total 48  drwxr-xr-x  3 ubuntu ubuntu")
                .font(.custom(fontFamily, size: fontSize))
                .foregroundColor(Color.white.opacity(0.6))

            Text("drwxr-xr-x  2 ubuntu ubuntu  4096 Jan  1 12:00 .")
                .font(.custom(fontFamily, size: fontSize))
                .foregroundColor(Color.white.opacity(0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.terminalPreviewBg)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
    }

    // MARK: - 光标配置 Section

    private var cursorSectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("光标")

            VStack(alignment: .leading, spacing: 14) {
                // 形状选择
                HStack(spacing: 20) {
                    ForEach(CursorShape.allCases, id: \.self) { shape in
                        cursorShapeOption(shape)
                    }
                }

                // 闪烁设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("光标闪烁")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        Spacer()
                        Toggle("", isOn: $cursorBlink)
                            .toggleStyle(.switch).labelsHidden()
                    }

                    HStack {
                        Text("仅空闲时闪烁")
                            .font(.system(size: 12))
                            .foregroundColor(cursorBlink
                                ? DesignTokens.Colors.textSecondary
                                : DesignTokens.Colors.textTertiary)
                        Spacer()
                        Toggle("", isOn: $cursorBlinkIdleOnly)
                            .toggleStyle(.switch).labelsHidden()
                    }
                    .disabled(!cursorBlink)
                    .padding(.leading, 16)
                }
            }
            .padding(.top, 14)
        }
    }

    private func cursorShapeOption(_ shape: CursorShape) -> some View {
        let isSelected = cursorShape == shape
        return Button(action: { cursorShapeRaw = shape.rawValue }) {
            HStack(spacing: 6) {
                // 单选点
                Circle()
                    .fill(isSelected ? DesignTokens.Colors.accentPrimary : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(isSelected
                                ? DesignTokens.Colors.accentPrimary
                                : DesignTokens.Colors.textTertiary,
                                lineWidth: 1.5)
                    )
                    .frame(width: 12, height: 12)

                // 光标图示
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: shape.iconAspect.width, height: shape.iconAspect.height)
                    .clipShape(RoundedRectangle(cornerRadius: shape == .underline ? 0 : 1, style: .continuous))

                // 标签
                Text(shape.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected
                        ? DesignTokens.Colors.textPrimary
                        : DesignTokens.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 窗口配置 Section

    private var windowSectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("窗口")

            // 背景透明度
            HStack(spacing: 12) {
                Text("背景透明度")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 100, alignment: .leading)

                Slider(value: $bgOpacity, in: 0...100, step: 5)
                    .accentColor(DesignTokens.Colors.accentPrimary)

                Text("\(Int(bgOpacity))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.top, 14)
        }
    }
}

// MARK: - 主题卡片视图

/// 主题缩略图卡片
private struct ThemeCardView: View {

    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // 预览区（全宽自适应 × 44pt）
                ZStack(alignment: .topLeading) {
                    theme.background
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 3) {
                            Text("$")
                                .foregroundColor(theme.promptColor)
                            Text("ls")
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text("total 48")
                            .foregroundColor(theme.outputColor)
                    }
                    .font(.system(size: 8, design: .monospaced))
                    .padding(DesignTokens.Spacing.xs)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)

                // 标签区
                Text(theme.name)
                    .font(.system(size: 9.5))
                    .foregroundColor(isSelected
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .background(DesignTokens.Colors.surfacePanel)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        isSelected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.borderPrimary,
                        lineWidth: isSelected ? 2 : 0.75
                    )
            )
        }
        .buttonStyle(.plain)
        .help(theme.name)
    }
}


// MARK: - 自定义主题编辑器

/// 自定义颜色主题创建弹窗
private struct CustomThemeEditorSheet: View {

    var onSave: (AppTheme) -> Void
    var onCancel: () -> Void

    @State private var themeName: String = "我的主题"
    @State private var bgColor: Color = Color(hex: "#1C1C1E")
    @State private var promptColor: Color = Color(hex: "#30D158")
    @State private var outputColor: Color = Color(hex: "#EBEBF5")

    // 基础 ANSI 调色板（创建自定义主题时作为底板）
    private let baseAnsi = [
        "#1C1C1E", "#FF3B30", "#34C759", "#FF9500",
        "#007AFF", "#AF52DE", "#32ADE6", "#8E8E93",
        "#48484A", "#FF6961", "#6FD19B", "#FFD60A",
        "#409CFF", "#C969E1", "#5AC8FA", "#FFFFFF"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("创建自定义主题")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // 编辑区
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 主题名称
                HStack(spacing: 12) {
                    Text("主题名称")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 76, alignment: .leading)
                    CustomTextField(placeholder: "输入主题名称", text: $themeName)
                        .font(.system(size: 12))
                }

                Divider()

                // 颜色选择
                VStack(spacing: DesignTokens.Spacing.md) {
                    colorRow("背景色", color: $bgColor)
                    colorRow("提示符色", color: $promptColor)
                    colorRow("文字色", color: $outputColor)
                }

                Divider()

                // 实时预览
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 3) {
                        Text("$")
                            .foregroundColor(promptColor)
                        Text("ls -la")
                            .foregroundColor(outputColor)
                    }
                    Text("total 48  drwxr-xr-x  ubuntu ubuntu")
                        .foregroundColor(outputColor.opacity(0.60))
                    Text("-rwxr-xr-x  1 ubuntu 4096 Jan 1 app.sh")
                        .foregroundColor(outputColor.opacity(0.45))
                }
                .font(.system(size: 11, design: .monospaced))
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .buttonStyle(.bordered)
                Button("保存主题") { saveTheme() }
                    .buttonStyle(.borderedProminent)
                    .disabled(themeName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Colors.surfacePanel)
    }

    private func colorRow(_ label: LocalizedStringKey, color: Binding<Color>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 76, alignment: .leading)

            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)

            // 颜色预览块
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                .fill(color.wrappedValue)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                        .stroke(DesignTokens.Colors.borderPrimary, lineWidth: 0.75)
                )

            Text(color.wrappedValue.toHex().uppercased())
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    private func saveTheme() {
        let name = themeName.trimmingCharacters(in: .whitespaces)
        let timestamp = Int(Date().timeIntervalSince1970)
        let id = "custom-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))-\(timestamp)"

        // 将选定主色注入 ANSI 调色板的关键槽
        var ansi = baseAnsi
        ansi[2]  = promptColor.toHex()          // ANSI 绿 → 提示符色
        ansi[7]  = outputColor.toHex()           // ANSI 白 → 文字色
        ansi[10] = promptColor.toHex()           // ANSI 亮绿
        ansi[15] = outputColor.toHex()           // ANSI 亮白

        let theme = AppTheme(
            id: id,
            name: name,
            backgroundHex: bgColor.toHex(),
            promptHex: promptColor.toHex(),
            outputHex: outputColor.toHex(),
            ansiColors: ansi
        )
        onSave(theme)
    }
}

// MARK: - 预览

#Preview("外观设置") {
    AppearanceSettingsView()
        .frame(width: 480, height: 520)
        .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("自定义主题编辑器") {
    CustomThemeEditorSheet(onSave: { _ in }, onCancel: {})
        .frame(width: 400, height: 480)
}
