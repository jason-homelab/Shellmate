import SwiftUI

// MARK: - 终端主题定义

/// 内置终端颜色主题
struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let background: Color
    let promptColor: Color
    let outputColor: Color

    static let builtins: [AppTheme] = {
        let shellmateDark  = AppTheme(id: "shellmate-dark",   name: "ShellMate Dark",   background: Color(hex: "#0C0C0E"), promptColor: Color(hex: "#4CAF7D"), outputColor: Color(hex: "#8E8E9A"))
        let shellmateLight = AppTheme(id: "shellmate-light",  name: "ShellMate Light",  background: Color(hex: "#FFFFFF"), promptColor: Color(hex: "#1E8C52"), outputColor: Color(hex: "#6B6B7B"))
        let solarizedDark  = AppTheme(id: "solarized-dark",   name: "Solarized Dark",   background: Color(hex: "#002B36"), promptColor: Color(hex: "#859900"), outputColor: Color(hex: "#657B83"))
        let solarizedLight = AppTheme(id: "solarized-light",  name: "Solarized Light",  background: Color(hex: "#FDF6E3"), promptColor: Color(hex: "#657B83"), outputColor: Color(hex: "#93A1A1"))
        let dracula        = AppTheme(id: "dracula",           name: "Dracula",          background: Color(hex: "#282A36"), promptColor: Color(hex: "#BD93F9"), outputColor: Color(hex: "#6272A4"))
        let oneDark        = AppTheme(id: "one-dark",          name: "One Dark",         background: Color(hex: "#282C34"), promptColor: Color(hex: "#98C379"), outputColor: Color(hex: "#5C6370"))
        let nord           = AppTheme(id: "nord",              name: "Nord",             background: Color(hex: "#2E3440"), promptColor: Color(hex: "#88C0D0"), outputColor: Color(hex: "#4C566A"))
        let gruvbox        = AppTheme(id: "gruvbox",           name: "Gruvbox",          background: Color(hex: "#282828"), promptColor: Color(hex: "#B8BB26"), outputColor: Color(hex: "#928374"))
        return [shellmateDark, shellmateLight, solarizedDark, solarizedLight, dracula, oneDark, nord, gruvbox]
    }()
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
    @AppStorage("appearance.fontFamily")      private var fontFamily: String = "JetBrains Mono"
    @AppStorage("appearance.fontSize")        private var fontSize: Double = 13
    @AppStorage("appearance.lineSpacing")     private var lineSpacing: Double = 1.4
    @AppStorage("appearance.ligatures")       private var ligatures: Bool = false
    @AppStorage("appearance.nonAsciiFontFamily") private var nonAsciiFont: String = "冬青黑体"
    @AppStorage("appearance.cursorShape")     private var cursorShapeRaw: String = CursorShape.block.rawValue
    @AppStorage("appearance.cursorBlink")     private var cursorBlink: Bool = true
    @AppStorage("appearance.cursorBlinkIdleOnly") private var cursorBlinkIdleOnly: Bool = false
    @AppStorage("appearance.bgOpacity")       private var bgOpacity: Double = 0
    @AppStorage("appearance.vibrancy")        private var vibrancy: Bool = false
    @AppStorage("appearance.paddingTop")      private var paddingTop: Double = 4
    @AppStorage("appearance.paddingBottom")   private var paddingBottom: Double = 4
    @AppStorage("appearance.paddingLeft")     private var paddingLeft: Double = 6
    @AppStorage("appearance.paddingRight")    private var paddingRight: Double = 6

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

                Divider().padding(.vertical, 12)

                // S02-C：字体配置
                fontSectionView

                Divider().padding(.vertical, 12)

                // S02-E：光标配置
                cursorSectionView

                Divider().padding(.vertical, 12)

                // S02-F：窗口配置
                windowSectionView
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 颜色主题 Section

    private var themeSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("颜色主题")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 主题卡片网格
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(72), spacing: 10), count: 6),
                spacing: 10
            ) {
                ForEach(AppTheme.builtins) { theme in
                    ThemeCardView(
                        theme: theme,
                        isSelected: selectedThemeId == theme.id
                    ) {
                        selectedThemeId = theme.id
                    }
                }

                // 自定义占位
                customThemeCard
            }

            // 辅助按钮
            HStack(spacing: 8) {
                Button(action: {}) {
                    Label("导入 .itermcolors", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button(action: {}) {
                    Label("导出主题", systemImage: "square.and.arrow.up")
                        .font(.system(size: 11))
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }
        }
    }

    /// 自定义主题占位卡
    private var customThemeCard: some View {
        VStack(spacing: 0) {
            // 预览区
            ZStack {
                DesignTokens.Colors.surfaceCard
                Image(systemName: "plus")
                    .font(.system(size: 18))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .frame(width: 72, height: 40)

            // 标签
            Text("自定义")
                .font(.system(size: 9.5))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 72, height: 16)
                .background(DesignTokens.Colors.surfacePanel)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 1)
        )
    }

    // MARK: - 字体配置 Section

    private var fontSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("字体")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 字体族
            fontFamilyRow

            // 字号
            fontSizeRow

            // 行间距
            lineSpacingRow

            // 连字
            HStack(spacing: 8) {
                Toggle(isOn: $ligatures) {
                    Text("启用字体连字（Ligatures）")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .toggleStyle(.checkbox)

                Text("⚠ 需字体支持（Fira Code, JetBrains Mono）")
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            // 非 ASCII 字体
            nonAsciiRow

            // 实时预览
            fontPreviewArea
        }
    }

    private var fontFamilyRow: some View {
        HStack(spacing: 12) {
            Text("字体族")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)

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
            .frame(height: 28)
        }
    }

    private var fontSizeRow: some View {
        HStack(spacing: 12) {
            Text("字号")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)

            Slider(value: $fontSize, in: 8...32, step: 1)
                .accentColor(DesignTokens.Colors.accentPrimary)

            Text("\(Int(fontSize)) pt")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 44, alignment: .trailing)

            Button(action: { fontSize = max(8, fontSize - 1) }) {
                Image(systemName: "minus")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)

            Button(action: { fontSize = min(32, fontSize + 1) }) {
                Image(systemName: "plus")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
        }
    }

    private var lineSpacingRow: some View {
        HStack(spacing: 12) {
            Text("行间距")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)

            Slider(value: $lineSpacing, in: 0.8...2.0, step: 0.1)
                .accentColor(DesignTokens.Colors.accentPrimary)

            Text(String(format: "%.1f×", lineSpacing))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var nonAsciiRow: some View {
        HStack(spacing: 12) {
            Text("非 ASCII 字体")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 100, alignment: .leading)

            Picker("", selection: $nonAsciiFont) {
                Text("冬青黑体").tag("冬青黑体")
                Text("华文细黑").tag("华文细黑")
                Text("苹方").tag("苹方")
                Text("PingFang SC").tag("PingFang SC")
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Text("中文等宽字符")
                .font(.system(size: 9.5))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    private var fontPreviewArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("ubuntu@server:~$ ")
                    .foregroundColor(Color(hex: "#4CAF7D"))
                Text("ls -la")
                    .foregroundColor(.white)
            }
            .font(.custom(fontFamily, size: fontSize))

            Text("total 48  drwxr-xr-x  3 ubuntu ubuntu")
                .font(.custom(fontFamily, size: fontSize))
                .foregroundColor(Color.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 72)
        .background(Color(hex: "#0C0C0E"))
        .cornerRadius(7)
    }

    // MARK: - 光标配置 Section

    private var cursorSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("光标")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 形状选择
            HStack(spacing: 12) {
                ForEach(CursorShape.allCases, id: \.self) { shape in
                    cursorShapeOption(shape)
                }
            }

            // 闪烁设置
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $cursorBlink) {
                    Text("光标闪烁")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $cursorBlinkIdleOnly) {
                    Text("仅空闲时闪烁")
                        .font(.system(size: 12))
                        .foregroundColor(cursorBlink
                            ? DesignTokens.Colors.textSecondary
                            : DesignTokens.Colors.textTertiary)
                }
                .toggleStyle(.checkbox)
                .disabled(!cursorBlink)
                .padding(.leading, 14)
            }
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
                    .cornerRadius(shape == .underline ? 0 : 1)

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
        VStack(alignment: .leading, spacing: 10) {
            Text("窗口")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)

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

            // Vibrancy
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $vibrancy) {
                    Text("背景模糊 Vibrancy")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .toggleStyle(.checkbox)

                Text("开启后应用磨砂玻璃效果且可透见桌面")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.leading, 22)
            }

            // 终端内边距
            HStack(alignment: .center, spacing: 0) {
                Text("终端内边距")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 100, alignment: .leading)

                paddingInputGroup
            }
        }
    }

    /// 四向内边距输入组
    private var paddingInputGroup: some View {
        VStack(spacing: 4) {
            // 上
            paddingField(label: "上", value: $paddingTop)

            HStack(spacing: 4) {
                // 左
                paddingField(label: "左", value: $paddingLeft)

                // 中央示意图
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DesignTokens.Colors.borderPrimary, lineWidth: 1)
                        .frame(width: 36, height: 36)
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 1)
                        .frame(width: 22, height: 22)
                }
                .frame(width: 46, height: 36)

                // 右
                paddingField(label: "右", value: $paddingRight)
            }

            // 下
            paddingField(label: "下", value: $paddingBottom)
        }
    }

    private func paddingField(label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 2) {
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 46, height: 26)
                .font(.system(size: 11, design: .monospaced))
                .multilineTextAlignment(.center)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textTertiary)
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
                // 预览区（72×40）
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
                    .padding(6)
                }
                .frame(width: 72, height: 40)

                // 标签区（72×16）
                Text(theme.name)
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 72, height: 16)
                    .background(DesignTokens.Colors.surfacePanel)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.borderSecondary,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help(theme.name)
    }
}


// MARK: - 预览

#Preview("外观设置") {
    AppearanceSettingsView()
        .frame(width: 480, height: 520)
        .background(DesignTokens.Colors.surfaceWindow)
}
