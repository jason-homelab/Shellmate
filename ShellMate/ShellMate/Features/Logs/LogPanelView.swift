import SwiftUI

// MARK: - 颜色扩展（日志类型）

extension SessionLogEntry.LogType {
    /// 类型标签颜色
    var color: Color {
        switch self {
        case .info:    return DesignTokens.Colors.statusConnected
        case .warning: return DesignTokens.Colors.statusConnecting
        case .error:   return DesignTokens.Colors.statusError
        case .command: return DesignTokens.Colors.accentPrimary
        }
    }

    /// 行背景色（对齐 Figma bg-*-50）
    var rowBackground: Color {
        switch self {
        case .info:    return DesignTokens.Colors.surfaceCard.opacity(0.80)
        case .warning: return DesignTokens.Colors.statusConnecting.opacity(0.08)
        case .error:   return DesignTokens.Colors.statusError.opacity(0.08)
        case .command: return DesignTokens.Colors.accentPrimary.opacity(0.07)
        }
    }

    /// 行边框色（对齐 Figma border-*-200）
    var borderColor: Color {
        switch self {
        case .info:    return DesignTokens.Colors.borderPrimary
        case .warning: return DesignTokens.Colors.statusConnecting.opacity(0.30)
        case .error:   return DesignTokens.Colors.statusError.opacity(0.30)
        case .command: return DesignTokens.Colors.accentPrimary.opacity(0.25)
        }
    }
}

// MARK: - 日志面板视图（Figma-Spec-v2 §14 §4）

struct LogPanelView: View {

    // MARK: - 属性

    var onClose: () -> Void

    // MARK: - 状态

    @ObservedObject private var logStore = SessionLogStore.shared

    @State private var selectedType: SessionLogEntry.LogType? = nil  // nil = 全部
    @State private var searchText = ""
    @State private var selectedSession: String? = nil
    @State private var isPaused = false
    @State private var showExportConfirm = false

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
            filterBarView
            Divider()
            logListView
        }
        // 对齐 Figma §14：sm:max-w-[900px] rounded-2xl shadow-2xl border border-[#d2d2d7]/50
        .frame(width: 900)
        .frame(minHeight: 400, maxHeight: 640)
        .background(DesignTokens.Colors.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.50), radius: 32, x: 0, y: 16)
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignTokens.Colors.accentPrimary)

            VStack(alignment: .leading, spacing: 1) {
                Text("会话日志")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(selectedSession.map { "· \($0)" } ?? "所有会话")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            // 清空
            Button {
                if let session = selectedSession {
                    logStore.clearSession(session)
                } else {
                    logStore.clear()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("清空日志")

            // 导出
            Button {
                exportLogs()
            } label: {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("导出日志")
            .disabled(filteredEntries.isEmpty)

            // 暂停/继续
            Button {
                isPaused.toggle()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isPaused ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help(isPaused ? "继续滚动" : "暂停滚动")

            Divider().frame(height: 16)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 12)
    }

    // MARK: - 过滤栏

    private var filterBarView: some View {
        HStack(spacing: 8) {
            // 类型过滤 Select 下拉
            Picker("日志类型", selection: $selectedType) {
                Text("全部").tag(SessionLogEntry.LogType?.none)
                ForEach(SessionLogEntry.LogType.allCases, id: \.rawValue) { type in
                    Text(type.label).tag(Optional(type))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 100)
            .font(.system(size: 12))
            .pickerStyle(.menu)

            Spacer()

            // 搜索框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                TextField("搜索日志内容…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 160)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DesignTokens.Colors.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )

            // 会话过滤
            if !sessionNames.isEmpty {
                Picker("", selection: $selectedSession) {
                    Text("全部会话").tag(String?.none)
                    ForEach(sessionNames, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 150)
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 8)
        .background(DesignTokens.Colors.surfaceCard)
    }

    // MARK: - 日志列表

    private var logListView: some View {
        Group {
            if filteredEntries.isEmpty {
                emptyLogView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        // 对齐 Figma §14：卡片间距 space-y-2 = 8pt
                        LazyVStack(spacing: 6) {
                            ForEach(filteredEntries) { entry in
                                logRowView(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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
        .background(DesignTokens.Colors.surfacePanel)
    }

    private var emptyLogView: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("暂无日志")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("建立 SSH 连接后，终端输入/输出将记录在此")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func logRowView(_ entry: SessionLogEntry) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        // 对齐 Figma §14：backdrop-blur-sm rounded-lg border p-3
        return VStack(alignment: .leading, spacing: 4) {
            // 顶部行：类型标签 + 时间戳 + 会话名
            HStack(spacing: 6) {
                // 类型徽章（text-xs font-semibold uppercase）
                Text(entry.type.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(entry.type.color)

                Text(formatter.string(from: entry.timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Spacer()

                // Void: 会话名徽章
                Text(entry.sessionName)
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Capsule())
            }

            // Void: 内容文字
            Text(entry.content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.md)
        .background(entry.type.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(entry.type.borderColor, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
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
    // 填充一些测试数据
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
