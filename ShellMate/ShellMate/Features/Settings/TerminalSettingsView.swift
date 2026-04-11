import SwiftUI

// MARK: - S04 终端行为设置视图

/// S04 — 终端行为设置面板
/// 包含滚动缓冲区、编码与输入、会话日志、高级终端行为
struct TerminalSettingsView: View {

    // MARK: - 持久化设置 (@AppStorage)

    // 滚动缓冲区
    @AppStorage("terminal.scrollbackLines")        private var scrollbackLines: Int    = 5000
    @AppStorage("terminal.scrollToBottomOnOutput") private var scrollToBottom: Bool   = true
    @AppStorage("terminal.unlimitedScrollback")    private var unlimitedScrollback: Bool = false

    // 编码与输入
    @AppStorage("terminal.charset")               private var charset: String         = "UTF-8"
    @AppStorage("terminal.langEnv")               private var langEnv: String         = "en_US.UTF-8"
    @AppStorage("terminal.backspaceMode")         private var backspaceMode: String   = "DEL"
    @AppStorage("terminal.optionAsMeta")          private var optionAsMeta: Bool      = false

    // 会话日志
    @AppStorage("terminal.loggingEnabled")        private var loggingEnabled: Bool    = false
    @AppStorage("terminal.logDirectory")          private var logDirectory: String    = "~/Documents/ShellMate/Logs/"
    @AppStorage("terminal.logFilenameFormat")     private var logFilenameFormat: String = "{session}_{date}.log"
    @AppStorage("terminal.logTimestamp")          private var logTimestamp: Bool      = true

    // 高级
    @AppStorage("terminal.termType")              private var termType: String        = "xterm-256color"
    @AppStorage("terminal.bellEnabled")           private var bellEnabled: Bool       = true
    @AppStorage("terminal.visualBell")            private var visualBell: Bool        = false
    @AppStorage("terminal.pasteConfirm")          private var pasteConfirm: Bool      = true
    @AppStorage("terminal.rightClickMenu")        private var rightClickMenu: Bool    = true

    // MARK: - 常量

    private let charsets = ["UTF-8", "GBK", "GB18030", "Shift_JIS", "EUC-JP", "ISO-8859-1"]
    private let langOptions = ["系统默认", "en_US.UTF-8", "zh_CN.UTF-8", "zh_TW.UTF-8", "ja_JP.UTF-8"]
    private let backspaceModes = ["ASCII DEL (^?)", "ASCII BS (^H)"]
    private let termTypes = ["xterm-256color", "xterm", "vt100", "screen-256color"]
    private let logFormats = ["{session}_{date}.log", "{date}_{session}.log", "{host}_{date}.log"]

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ① 滚动缓冲区
                settingsSection(title: "滚动缓冲区") {
                    scrollbackSection
                }

                Divider().padding(.vertical, 14)

                // ② 编码与输入
                settingsSection(title: "编码与输入") {
                    encodingSection
                }

                Divider().padding(.vertical, 14)

                // ③ 会话日志
                settingsSection(title: "会话日志") {
                    loggingSection
                }

                Divider().padding(.vertical, 14)

                // ④ 高级
                settingsSection(title: "高级") {
                    advancedSection
                }
            }
            .padding(18)
        }
    }

    // MARK: - 滚动缓冲区

    private var scrollbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("缓冲行数")
                    .frame(width: 100, alignment: .leading)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                TextField("", value: $scrollbackLines,
                          formatter: boundedIntFormatter(1000, 100000))
                    .textFieldStyle(.plain)
                    .frame(width: 80)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(6)
                    .background(DesignTokens.Colors.surfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5))
                    .disabled(unlimitedScrollback)

                Text("行")
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
            }

            Text("较大值占用更多内存")
                .font(.system(size: 9.5))
                .foregroundColor(DesignTokens.Colors.textDisabled)

            HStack {
                Text("滚动时跳转到底部（新内容时自动回底部）")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $scrollToBottom)
                    .toggleStyle(.switch).labelsHidden()
            }

            HStack {
                Text("无限滚动缓冲区")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $unlimitedScrollback)
                    .toggleStyle(.switch).labelsHidden()
            }

            if unlimitedScrollback {
                Text("开启后忽略上方行数限制，注意内存占用")
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .padding(.leading, 22)
            }
        }
    }

    // MARK: - 编码与输入

    private var encodingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            pickerRow(label: "字符编码", selection: $charset, options: charsets)
            pickerRow(label: "LANG 变量", selection: $langEnv, options: langOptions)
            pickerRow(label: "退格键映射", selection: $backspaceMode, options: backspaceModes)

            HStack {
                Text("Option 键作为 Meta 键（Alt）")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $optionAsMeta)
                    .toggleStyle(.switch).labelsHidden()
            }

            if optionAsMeta {
                Text("关闭后 Option 用于输入特殊字符（如 ™ © 等）")
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .padding(.leading, 22)
            }
        }
    }

    // MARK: - 会话日志

    private var loggingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("启用会话日志记录")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $loggingEnabled)
                    .toggleStyle(.switch).labelsHidden()
            }

            if loggingEnabled {
                HStack(spacing: 8) {
                    Text("日志目录")
                        .frame(width: 100, alignment: .leading)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    CustomTextField(placeholder: "~/Documents/ShellMate/Logs/", text: $logDirectory)

                    Button("选择…") {
                        pickLogDirectory()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                pickerRow(label: "文件名格式", selection: $logFilenameFormat, options: logFormats)

                HStack {
                    Text("日志中记录时间戳")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Spacer()
                    Toggle("", isOn: $logTimestamp)
                        .toggleStyle(.switch).labelsHidden()
                }
            }
        }
    }

    // MARK: - 高级

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            pickerRow(label: "TERM 变量", selection: $termType, options: termTypes)

            HStack {
                Text("响铃（Bell）")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $bellEnabled)
                    .toggleStyle(.switch).labelsHidden()
            }

            if bellEnabled {
                Text("接收到 BEL 字符时播放系统提示音")
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .padding(.leading, 22)
            }

            HStack {
                Text("窗口闪烁提醒（Visual Bell）")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $visualBell)
                    .toggleStyle(.switch).labelsHidden()
            }

            HStack {
                Text("多行粘贴时弹出确认框")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $pasteConfirm)
                    .toggleStyle(.switch).labelsHidden()
            }

            if pasteConfirm {
                Text("防止误粘贴包含换行的命令直接执行")
                    .font(.system(size: 9.5))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .padding(.leading, 22)
            }

            HStack {
                Text("右键弹出上下文菜单（而非粘贴）")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $rightClickMenu)
                    .toggleStyle(.switch).labelsHidden()
            }
        }
    }

    // MARK: - 辅助组件

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            content()
        }
    }

    private func pickerRow(label: LocalizedStringKey, selection: Binding<String>, options: [String]) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 100, alignment: .leading)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func boundedIntFormatter(_ min: Int, _ max: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = NSNumber(value: min)
        f.maximum = NSNumber(value: max)
        return f
    }

    private func pickLogDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "选择日志保存目录"
        if panel.runModal() == .OK, let url = panel.url {
            logDirectory = url.path
        }
    }
}

// MARK: - 预览

#Preview("终端设置") {
    TerminalSettingsView()
        .frame(width: 480, height: 520)
}
