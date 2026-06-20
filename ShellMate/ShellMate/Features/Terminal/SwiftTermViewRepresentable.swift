import SwiftUI
import SwiftTerm
import AppKit

// MARK: - SwiftTerm NSViewRepresentable 包装器

/// 将 SwiftTerm 的 AppKit TerminalView 包装为 SwiftUI 视图
struct SwiftTermViewRepresentable: NSViewRepresentable {

    /// 外部持有终端视图引用（用于调用 feed/font 等操作）
    @Binding var viewRef: SwiftTerm.TerminalView?
    /// 委托（TerminalController）
    var controller: TerminalController
    /// 当前字号
    var fontSize: CGFloat
    /// 当前字体族名称（PostScript 名，空字符串时回退到系统等宽字体）
    var fontFamily: String
    /// 当前主题 ID（从 AppStorage 传入，变化时触发 updateNSView）
    var themeId: String
    /// Option 键作为 Meta 键（对齐 terminal.optionAsMeta AppStorage）
    var optionAsMeta: Bool

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView(frame: .zero)
        view.terminalDelegate = controller
        view.font = resolvedFont()
        view.optionAsMetaKey = optionAsMeta
        applyTheme(themeId, to: view)
        // 延迟赋值避免 SwiftUI 状态更新循环
        Task { @MainActor in viewRef = view }
        return view
    }

    func updateNSView(_ nsView: SwiftTerm.TerminalView, context: Context) {
        let resolved = resolvedFont()
        if nsView.font.fontName != resolved.fontName || nsView.font.pointSize != resolved.pointSize {
            nsView.font = resolved
        }
        if nsView.optionAsMetaKey != optionAsMeta {
            nsView.optionAsMetaKey = optionAsMeta
        }
        applyTheme(themeId, to: nsView)
    }

    private func resolvedFont() -> NSFont {
        if !fontFamily.isEmpty, let custom = NSFont(name: fontFamily, size: fontSize) {
            return custom
        }
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    // MARK: - 主题应用

    private func applyTheme(_ id: String, to view: SwiftTerm.TerminalView) {
        let theme = AppTheme.allThemes.first(where: { $0.id == id }) ?? AppTheme.builtins[0]
        // 设置背景色和前景色
        view.nativeBackgroundColor = NSColor(theme.background)
        view.nativeForegroundColor = NSColor(theme.outputColor)
        // 安装完整的 16 色 ANSI 调色板
        if theme.ansiColors.count == 16 {
            let palette = theme.ansiColors.map { hexToSwiftTermColor($0) }
            view.installColors(palette)
        }
    }

    /// 将十六进制颜色字符串转换为 SwiftTerm.Color（8 位值扩展为 16 位）
    private func hexToSwiftTermColor(_ hex: String) -> SwiftTerm.Color {
        let stripped = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: stripped).scanHexInt64(&int)
        let r = UInt16((int >> 16) & 0xFF)
        let g = UInt16((int >> 8)  & 0xFF)
        let b = UInt16(int         & 0xFF)
        // 8 位 → 16 位：r8 * 257 = r8 << 8 | r8（保证 0 → 0，255 → 65535 线性映射）
        return SwiftTerm.Color(red: r << 8 | r, green: g << 8 | g, blue: b << 8 | b)
    }
}
