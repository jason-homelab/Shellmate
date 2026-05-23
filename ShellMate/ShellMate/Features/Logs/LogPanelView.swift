import SwiftUI

// MARK: - 颜色扩展（日志类型）

extension SessionLogEntry.LogType {
    var color: Color {
        switch self {
        case .info:    return DesignTokens.Colors.statusConnected
        case .warning: return DesignTokens.Colors.statusConnecting
        case .error:   return DesignTokens.Colors.statusError
        case .command: return DesignTokens.Colors.accentPrimary
        }
    }

    var rowBackground: Color {
        switch self {
        case .info:    return Color.white.opacity(0.80)
        case .warning: return DesignTokens.Colors.statusConnecting.opacity(0.08)
        case .error:   return DesignTokens.Colors.statusError.opacity(0.08)
        case .command: return DesignTokens.Colors.accentPrimary.opacity(0.07)
        }
    }

    var borderColor: Color {
        switch self {
        case .info:    return DesignTokens.Colors.borderPrimary
        case .warning: return DesignTokens.Colors.statusConnecting.opacity(0.30)
        case .error:   return DesignTokens.Colors.statusError.opacity(0.30)
        case .command: return DesignTokens.Colors.accentPrimary.opacity(0.25)
        }
    }
}

// MARK: - 日志面板视图（Figma LogViewerDialog.tsx 1:1）

struct LogPanelView: View {

    // MARK: - Tab 枚举

    private enum LogTab: String, CaseIterable {
        case viewer  = "日志查看"
        case settings = "设置"
    }

    // MARK: - 属性

    var onClose: () -> Void

    // MARK: - 状态

    @ObservedObject private var logStore = SessionLogStore.shared

    @State private var activeLogTab: LogTab = .viewer
    @State private var selectedType: SessionLogEntry.LogType? = nil
    @State private var searchText = ""
    @State private var selectedSession: String? = nil
    @State private var isPaused = false

    // 设置 Tab 状态
    @State private var autoSave: Bool = true
    @State private var maxEntries: String = "1000"
    @State private var logSavePath: String = "~/Documents/TerminalLogs"
    @State private var includeTimestamps: Bool = true

    // MARK: - 过滤

    private var filteredEntries: [SessionLogEntry] {
        logStore.entries.filter { entry in
            if let type = selectedType, entry.type != type { return false }
            if let session = selectedSession, entry.sessionName != session { return false }
            if !searchText.isEmpty {
                return entry.content.localizedCaseInsensitiveContains(searchText)
                    || entry.sessionName.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
    }

    private var sessionNames: [String] {
        Array(Set(logStore.entries.map(\.sessionName))).sorted()
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            tabSelectorRow
            if activeLogTab == .viewer {
                filterBarView
                Divider()
                logListView
            } else {
                settingsTabView
            }
        }
        // Figma 19:2: 700px white card, rounded-2xl, shadow
        .frame(width: 700)
        .frame(minHeight: 400, maxHeight: 640)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.below.ecg")
                .font(DesignTokens.Typography.labelXLarge)
                .foregroundColor(DesignTokens.Colors.accentPrimary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.px) {
                Text("会话日志")
                    .font(DesignTokens.Typography.bodyLargeStrong)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(selectedSession.map { "· \($0)" } ?? "所有会话")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Button {
                if let session = selectedSession {
                    logStore.clearSession(session)
                } else {
                    logStore.clear()
                }
            } label: {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("清空日志")

            Button { exportLogs() } label: {
                Image(systemName: "arrow.up.doc")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("导出日志")
            .disabled(filteredEntries.isEmpty)

            Button { isPaused.toggle() } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(isPaused ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help(isPaused ? "继续滚动" : "暂停滚动")

            Divider().frame(height: 16)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Tab 切换栏（Figma grid-cols-2 bg-black/5 rounded-xl p-1）

    private var tabSelectorRow: some View {
        HStack(spacing: DesignTokens.Spacing.xxxs) {
            ForEach(LogTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { activeLogTab = tab }
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: activeLogTab == tab ? .medium : .regular))
                        .foregroundColor(activeLogTab == tab
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(activeLogTab == tab ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .shadow(color: activeLogTab == tab ? Color.black.opacity(0.08) : Color.clear,
                                radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.xxs)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    // MARK: - 过滤栏（viewer tab）

    private var filterBarView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Picker("日志类型", selection: $selectedType) {
                Text("全部").tag(SessionLogEntry.LogType?.none)
                ForEach(SessionLogEntry.LogType.allCases, id: \.rawValue) { type in
                    Text(type.label).tag(Optional(type))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 100)
            .font(DesignTokens.Typography.bodySmall)
            .pickerStyle(.menu)

            Spacer()

            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                TextField("搜索日志内容…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.bodySmall)
                    .frame(width: 160)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(DesignTokens.Typography.captionLarge)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.micro)
            // Figma 19:4: bg-[rgba(0,0,0,0.05)] rounded-[8px]
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if !sessionNames.isEmpty {
                Picker("", selection: $selectedSession) {
                    Text("全部会话").tag(String?.none)
                    ForEach(sessionNames, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 150)
                .font(DesignTokens.Typography.bodySmall)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(Color.white.opacity(0.60))
        }
    }

    // MARK: - 日志列表（viewer tab）

    private var logListView: some View {
        Group {
            if filteredEntries.isEmpty {
                emptyLogView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DesignTokens.Spacing.xs) {
                            ForEach(filteredEntries) { entry in
                                logRowView(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                    }
                    .onChange(of: logStore.entries.count) { _ in
                        if !isPaused, let last = filteredEntries.last {
                            withAnimation(.none) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(DesignTokens.Colors.surfaceWindow)
    }

    private var emptyLogView: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(DesignTokens.Typography.displayLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("暂无日志")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("建立 SSH 连接后，终端输入/输出将记录在此")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func logRowView(_ entry: SessionLogEntry) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(entry.type.label.uppercased())
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(entry.type.color)

                Text(formatter.string(from: entry.timestamp))
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Spacer()

                Text(entry.sessionName)
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xxxs)
                    .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
                    .clipShape(Capsule())
            }

            Text(entry.content)
                .font(DesignTokens.Typography.codeTiny)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.md)
        .background(entry.type.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(entry.type.borderColor, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }

    // MARK: - 设置 Tab（Figma settings TabsContent）

    private var settingsTabView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                // 自动保存
                settingsToggleRow(
                    title: "自动保存日志",
                    description: "将终端命令和输出自动保存到本地文件",
                    isOn: $autoSave
                )

                // 最大条目数
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("最大日志条目数")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    CustomTextField(placeholder: "例如：1000", text: $maxEntries)
                        .font(DesignTokens.Typography.bodySmall)
                    Text("超过上限时自动丢弃最旧的条目")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.surfaceWindow)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))

                // 保存路径
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("日志保存路径")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    CustomTextField(placeholder: "~/Documents/TerminalLogs", text: $logSavePath)
                        .font(DesignTokens.Typography.bodySmall)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.surfaceWindow)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))

                // 记录时间戳
                settingsToggleRow(
                    title: "记录时间戳",
                    description: "在每条日志条目中附加精确时间",
                    isOn: $includeTimestamps
                )
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func settingsToggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(title)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(description)
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceWindow)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - 导出

    private func exportLogs() {
        let text = logStore.exportText(filtered: filteredEntries)
        guard let data = text.data(using: .utf8) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "shellmate-logs-\(ISO8601DateFormatter().string(from: Date()).prefix(10)).txt"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - 通知名扩展

extension Notification.Name {
    static let logPanelRequested = Notification.Name("app.shellmate.logPanelRequested")
}

// MARK: - 预览

#Preview("日志面板") {
    let store = SessionLogStore.shared
    let names = ["ubuntu@192.168.1.1", "root@10.0.0.5"]
    let types = SessionLogEntry.LogType.allCases
    for i in 0..<30 {
        store.append(SessionLogEntry(
            timestamp: Date().addingTimeInterval(Double(-30 + i)),
            sessionName: names[i % 2],
            type: types[i % types.count],
            content: "示例日志第 \(i + 1) 条 — ls -la /home/ubuntu"
        ))
    }
    return LogPanelView(onClose: {})
}
