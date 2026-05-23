import SwiftUI
import SwiftTerm
import AppKit

// MARK: - 本地终端视图（任务 13.7）

/// 本地 Shell 标签页视图
/// 无需 SSH 连接，通过 POSIX PTY 运行本地 Shell（对标 iTerm2 本地标签）
struct LocalTerminalView: View {

    // MARK: - 外部依赖（可选：TabBarStore 集成，PRD §3.4.0）

    /// 对应标签页 ID（用于同步标题 / 状态至 TabBarStore）
    var tabId: UUID? = nil
    /// TabBarStore 引用（用于同步标题 / 状态）
    var tabBarStore: TabBarStore? = nil

    // MARK: - 控制器

    @StateObject private var controller = LocalTerminalController()

    // MARK: - 外观设置

    @AppStorage("appearance.fontSize")   private var fontSize: Double = 13
    @AppStorage("appearance.fontFamily") private var fontFamily: String = ""
    @AppStorage("appearance.themeId")    private var themeId: String = "shellmate-dark"
    @AppStorage("terminal.optionAsMeta") private var optionAsMeta: Bool = false

    // MARK: - 内部状态

    @State private var terminalViewRef: SwiftTerm.TerminalView?

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 终端工具栏（字号控制 + 清屏）
            LocalTerminalToolbarView(
                title: controller.terminalTitle,
                fontSize: $fontSize,
                onClear: {
                    // SwiftTerm 没有 clearScreen API，用 RIS（Reset to Initial State）序列清屏
                    let ris = [UInt8]("\u{1B}c".utf8)
                    terminalViewRef?.feed(byteArray: ris[...])
                }
            )

            Divider()

            // 终端内容
            ZStack {
                LocalSwiftTermRepresentable(
                    viewRef: $terminalViewRef,
                    controller: controller,
                    fontSize: CGFloat(fontSize),
                    fontFamily: fontFamily,
                    themeId: themeId,
                    optionAsMeta: optionAsMeta
                )

                // 终止状态覆层
                if case .terminated(let code) = controller.state {
                    terminatedOverlay(exitCode: code)
                }
            }

            // 状态栏
            TerminalStatusBarView(connectionState: .connected)
        }
        .onAppear {
            controller.start()
        }
        .onDisappear {
            controller.terminate()
        }
        // 标题同步：Shell OSC 2 更新标题 → TerminalTab.title（PRD §3.4.0）
        .onChange(of: controller.terminalTitle) { newTitle in
            guard let id = tabId, let store = tabBarStore else { return }
            store.updateTitle(for: id, title: newTitle)
        }
        // 状态同步：Shell 进程运行 → .connected（绿），退出 → .offline（灰）（PRD §3.4.0）
        .onChange(of: controller.state) { newState in
            guard let id = tabId, let store = tabBarStore else { return }
            switch newState {
            case .running:
                store.updateConnectionState(for: id, state: .connected)
            case .terminated:
                store.updateConnectionState(for: id, state: .offline)
            case .idle:
                break
            }
        }
    }

    // MARK: - 终止覆层

    private func terminatedOverlay(exitCode: Int32) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "terminal")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("Shell 已退出")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            if exitCode != 0 {
                Text("退出码: \(exitCode)")
                    .font(DesignTokens.Typography.codeMedium)
                    .foregroundColor(DesignTokens.Colors.statusError)
            }

            Button("重新启动") {
                let ris = [UInt8]("\u{1B}c".utf8)
                terminalViewRef?.feed(byteArray: ris[...])
                controller.restart()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.terminalBackground)
    }
}

// MARK: - NSViewRepresentable 包装器（本地终端专用）

/// 为 LocalTerminalController 包装 SwiftTerm.TerminalView
struct LocalSwiftTermRepresentable: NSViewRepresentable {

    @Binding var viewRef: SwiftTerm.TerminalView?
    var controller: LocalTerminalController
    var fontSize: CGFloat
    var fontFamily: String
    var themeId: String
    var optionAsMeta: Bool

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView(frame: .zero)
        view.terminalDelegate = controller
        view.font = resolvedFont()
        view.optionAsMetaKey = optionAsMeta
        applyTheme(themeId, to: view)
        // 通知控制器持有视图引用（用于 feed 数据）
        Task { @MainActor in
            viewRef = view
            controller.terminalView = view
        }
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

    private func applyTheme(_ id: String, to view: SwiftTerm.TerminalView) {
        let theme = AppTheme.allThemes.first(where: { $0.id == id }) ?? AppTheme.builtins[0]
        view.nativeBackgroundColor = NSColor(theme.background)
        view.nativeForegroundColor = NSColor(theme.outputColor)
        // ansiColors 是 [String]（hex），转为 SwiftTerm.Color 数组后一次性安装
        if theme.ansiColors.count == 16 {
            let palette = theme.ansiColors.map { hexToSwiftTermColor($0) }
            view.installColors(palette)
        }
    }

    /// 十六进制颜色字符串 → SwiftTerm.Color（8位值扩展为16位）
    private func hexToSwiftTermColor(_ hex: String) -> SwiftTerm.Color {
        let stripped = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: stripped).scanHexInt64(&int)
        let r = UInt16((int >> 16) & 0xFF)
        let g = UInt16((int >> 8)  & 0xFF)
        let b = UInt16(int         & 0xFF)
        return SwiftTerm.Color(red: r << 8 | r, green: g << 8 | g, blue: b << 8 | b)
    }
}

// MARK: - 本地终端工具栏

private struct LocalTerminalToolbarView: View {

    let title: String
    @Binding var fontSize: Double
    let onClear: () -> Void

    private let minFontSize: Double = 9
    private let maxFontSize: Double = 32

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Shell 图标
            Image(systemName: "terminal.fill")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.accentPrimary)

            // 标题
            Text(title)
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            // 字号减小
            Button {
                fontSize = max(minFontSize, fontSize - 1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(DesignTokens.Typography.bodySmall)
            }
            .buttonStyle(.plain)
            .help("缩小字号")

            // 字号数值
            Text("\(Int(fontSize))pt")
                .font(DesignTokens.Typography.codeTiny)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 32, alignment: .center)

            // 字号增大
            Button {
                fontSize = min(maxFontSize, fontSize + 1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(DesignTokens.Typography.bodySmall)
            }
            .buttonStyle(.plain)
            .help("放大字号")

            Divider().frame(height: 16)

            // 清屏按钮
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.bodySmall)
            }
            .buttonStyle(.plain)
            .help("清屏")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 36)
        .background(DesignTokens.Colors.surfacePanel)
    }
}

// MARK: - 预览

#Preview {
    LocalTerminalView()
        .frame(width: 800, height: 600)
}
