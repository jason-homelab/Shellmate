import SwiftUI
import UniformTypeIdentifiers

// MARK: - 导入/导出弹窗（Figma-Spec-v2 §14 §3）

struct SessionImportExportView: View {

    // MARK: - 属性

    let sessions: [Session]
    var onImport: ([Session]) -> Void
    var onClose: () -> Void

    // MARK: - 导出状态

    @State private var activeTab: ExportTab = .export
    @State private var selectedSessionIds: Set<UUID> = []
    @State private var exportFormat: ExportFormat = .json

    // MARK: - 导入状态

    @State private var isDraggingOver = false
    @State private var importError: String?
    @State private var importPreview: [Session] = []
    @State private var showImportPreview = false

    enum ExportTab: String, CaseIterable {
        case export = "导出"
        case `import` = "导入"
    }

    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv  = "CSV"
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            tabPickerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 500)
        .frame(minHeight: 380, maxHeight: 560)
        .background(Color.white.opacity(0.95))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
        .onAppear {
            // 默认全选
            selectedSessionIds = Set(sessions.map(\.id))
        }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("导入 / 导出")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("备份、恢复或迁移会话配置（不含凭据）")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

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
        .padding(.vertical, 14)
    }

    // MARK: - Tab 选择器

    private var tabPickerView: some View {
        HStack(spacing: 2) {
            ForEach(ExportTab.allCases, id: \.rawValue) { tab in
                Button(action: { activeTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: activeTab == tab ? .semibold : .regular))
                        .foregroundColor(activeTab == tab
                            ? Color(hex: "#1d1d1f")
                            : Color(hex: "#6e6e73"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(activeTab == tab
                            ? Color.white.opacity(0.95)
                            : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: activeTab == tab ? Color.black.opacity(0.06) : .clear,
                                radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 10)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentView: some View {
        switch activeTab {
        case .export:
            exportTabContent
        case .import:
            importTabContent
        }
    }

    // MARK: - 导出 Tab

    private var exportTabContent: some View {
        VStack(spacing: 0) {
            // 格式选择 + 全选
            HStack {
                // 格式选择
                HStack(spacing: 6) {
                    Text("格式：")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    ForEach(ExportFormat.allCases, id: \.rawValue) { fmt in
                        Button(action: { exportFormat = fmt }) {
                            Text(fmt.rawValue)
                                .font(.system(size: 11, weight: exportFormat == fmt ? .semibold : .regular))
                                .foregroundColor(exportFormat == fmt
                                    ? DesignTokens.Colors.accentPrimary
                                    : DesignTokens.Colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(exportFormat == fmt
                                    ? DesignTokens.Colors.accentPrimary.opacity(0.10)
                                    : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button(allExportSelected ? "取消全选" : "全选") {
                    if allExportSelected {
                        selectedSessionIds.removeAll()
                    } else {
                        selectedSessionIds = Set(sessions.map(\.id))
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .buttonStyle(.plain)

                Text("\(selectedSessionIds.count)/\(sessions.count)")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, 8)
            .background(DesignTokens.Colors.surfaceCard)
            .overlay(Divider(), alignment: .bottom)

            // 会话复选框列表
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(sessions) { session in
                        sessionExportRow(session)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, 8)
            }
        }
    }

    private var allExportSelected: Bool {
        !sessions.isEmpty && sessions.allSatisfy { selectedSessionIds.contains($0.id) }
    }

    private func sessionExportRow(_ session: Session) -> some View {
        let isSelected = selectedSessionIds.contains(session.id)
        return HStack(spacing: 10) {
            Button {
                if isSelected { selectedSessionIds.remove(session.id) }
                else { selectedSessionIds.insert(session.id) }
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("\(session.username)@\(session.host):\(session.port)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected
            ? DesignTokens.Colors.accentPrimary.opacity(0.04)
            : Color.white.opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isSelected
                    ? DesignTokens.Colors.accentPrimary.opacity(0.20)
                    : Color(hex: "#d2d2d7").opacity(0.40), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected { selectedSessionIds.remove(session.id) }
            else { selectedSessionIds.insert(session.id) }
        }
    }

    // MARK: - 导入 Tab

    private var importTabContent: some View {
        VStack(spacing: 12) {
            // 拖拽区域
            dropZoneView
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.top, DesignTokens.Spacing.md)

            // 格式说明
            formatHintView

            // 或提示
            HStack {
                VStack { Divider() }
                Text("或")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, 8)
                VStack { Divider() }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            // 手动选择文件按钮
            Button {
                pickImportFile()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 13))
                    Text("选择文件…")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, DesignTokens.Spacing.lg)

            if let error = importError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
            }

            Spacer()
        }
    }

    private var dropZoneView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDraggingOver
                        ? DesignTokens.Colors.accentPrimary
                        : Color(hex: "#d2d2d7").opacity(0.60),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isDraggingOver
                            ? DesignTokens.Colors.accentPrimary.opacity(0.05)
                            : Color.clear)
                )

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 28))
                    .foregroundColor(isDraggingOver
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textTertiary)
                Text("将会话文件拖到这里")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                // 支持格式 badge 列表
                HStack(spacing: 6) {
                    ForEach(["JSON", "XSH", "INI", "REG"], id: \.self) { fmt in
                        Text(fmt)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
            .padding(24)
        }
        .frame(height: 140)
        .onDrop(of: [UTType.json, UTType.fileURL, UTType.data], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    // MARK: - 支持格式说明

    private var formatHintView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("支持格式")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                ForEach([
                    ("JSON", "ShellMate 导出格式"),
                    ("XSH",  "Xshell 5/6/7 会话文件"),
                    ("INI",  "SecureCRT 会话文件"),
                    ("REG",  "PuTTY 注册表导出")
                ], id: \.0) { fmt, desc in
                    HStack(spacing: 6) {
                        Text(".\(fmt.lowercased())")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                            .frame(width: 36, alignment: .leading)
                        Text(desc)
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }

    // MARK: - 底部

    private var footerView: some View {
        HStack {
            Spacer()
            Button("关闭", action: onClose)
                .buttonStyle(.bordered)

            if activeTab == .export {
                Button {
                    performExport()
                } label: {
                    Label("导出", systemImage: "arrow.up.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSessionIds.isEmpty)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - 导出逻辑

    private func performExport() {
        let toExport = sessions.filter { selectedSessionIds.contains($0.id) }
        switch exportFormat {
        case .json: exportAsJSON(toExport)
        case .csv:  exportAsCSV(toExport)
        }
    }

    private func exportAsJSON(_ sessions: [Session]) {
        struct SessionExport: Encodable {
            let version: Int = 1
            let exportedAt: String
            let sessions: [SessionRecord]
        }
        struct SessionRecord: Encodable {
            let name, host, username, encoding: String
            let port: Int32
            let authMethodRaw: Int16
            let keepAliveInterval, connectTimeout: Int32
            let autoReconnect: Bool
            let tags: [String]
            let proxyJumpString: String?
            let startupCommand: String?
        }

        let records = sessions.map { s in
            SessionRecord(
                name: s.name, host: s.host, username: s.username, encoding: s.encoding,
                port: s.port, authMethodRaw: s.authMethod.rawValue,
                keepAliveInterval: s.keepAliveInterval, connectTimeout: s.connectTimeout,
                autoReconnect: s.autoReconnect, tags: s.tags,
                proxyJumpString: s.proxyJumpString, startupCommand: s.startupCommand
            )
        }
        let export = SessionExport(
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            sessions: records
        )
        guard let data = try? JSONEncoder().encode(export) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "shellmate-sessions-\(datePrefix()).json"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func exportAsCSV(_ sessions: [Session]) {
        var lines = ["名称,主机,端口,用户名,认证方式,标签,跳板机,启动命令"]
        for s in sessions {
            let cols = [
                csvEscape(s.name), csvEscape(s.host),
                "\(s.port)", csvEscape(s.username),
                s.authMethod == .password ? "密码" : "私钥",
                csvEscape(s.tags.joined(separator: ";")),
                csvEscape(s.proxyJumpString ?? ""),
                csvEscape(s.startupCommand ?? "")
            ]
            lines.append(cols.joined(separator: ","))
        }
        let csvText = lines.joined(separator: "\n")
        guard let data = csvText.data(using: .utf8) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "csv") ?? .commaSeparatedText]
        panel.nameFieldStringValue = "shellmate-sessions-\(datePrefix()).csv"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - 导入逻辑

    private func handleDrop(providers: [NSItemProvider]) {
        importError = nil
        for provider in providers {
            // 优先尝试 fileURL（以获取扩展名）
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil)
                    else { return }
                    DispatchQueue.main.async {
                        if let fileData = try? Data(contentsOf: url) {
                            processImportData(fileData, fileExtension: url.pathExtension)
                        } else {
                            self.importError = "无法读取文件内容"
                        }
                    }
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.json.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.json.identifier) { data, _ in
                    DispatchQueue.main.async {
                        if let data { self.processImportData(data, fileExtension: "json") }
                        else { self.importError = "无法读取文件内容" }
                    }
                }
                return
            }
        }
        importError = "请拖入支持的会话文件（.json / .xsh / .ini / .reg）"
    }

    private func pickImportFile() {
        importError = nil
        let panel = NSOpenPanel()
        // 同时支持 JSON / XSH / INI / REG
        let xsh = UTType(filenameExtension: "xsh") ?? .data
        let ini = UTType(filenameExtension: "ini") ?? .data
        let reg = UTType(filenameExtension: "reg") ?? .data
        panel.allowedContentTypes = [.json, xsh, ini, reg]
        panel.allowsMultipleSelection = false
        panel.prompt = "导入"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url)
        else { return }
        processImportData(data, fileExtension: url.pathExtension)
    }

    private func processImportData(_ data: Data, fileExtension: String = "json") {
        let ext = fileExtension.lowercased()

        // ShellMate 原生 JSON 格式
        if ext == "json" {
            struct SessionExport: Decodable {
                let version: Int
                let sessions: [SessionRecord]
            }
            struct SessionRecord: Decodable {
                let name, host, username, encoding: String
                let port: Int32
                let authMethodRaw: Int16
                let keepAliveInterval, connectTimeout: Int32
                let autoReconnect: Bool
                let tags: [String]
                let proxyJumpString: String?
                let startupCommand: String?
            }

            guard let export = try? JSONDecoder().decode(SessionExport.self, from: data) else {
                importError = "文件格式不正确，请确保是 ShellMate JSON 导出文件"
                return
            }

            let sessions = export.sessions.map { record -> Session in
                let authMethod = AuthMethod(rawValue: record.authMethodRaw) ?? .password
                return Session(
                    name: record.name, host: record.host, port: record.port,
                    username: record.username, authMethod: authMethod,
                    keepAliveInterval: record.keepAliveInterval, autoReconnect: record.autoReconnect,
                    encoding: record.encoding, tags: record.tags,
                    proxyJumpString: record.proxyJumpString, connectTimeout: record.connectTimeout,
                    startupCommand: record.startupCommand
                )
            }
            onImport(sessions)
            onClose()
            return
        }

        // 竞品格式：Xshell / SecureCRT / PuTTY（任务 15.7）
        do {
            let sessions = try SessionFormatParser.parse(data: data, fileExtension: ext)
            onImport(sessions)
            onClose()
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - 辅助

    private func datePrefix() -> String {
        String(ISO8601DateFormatter().string(from: Date()).prefix(10))
    }

    private func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}

// MARK: - 预览

#Preview("导入/导出弹窗") {
    SessionImportExportView(
        sessions: [
            Session(name: "开发服务器", host: "192.168.1.100", username: "ubuntu"),
            Session(name: "生产环境", host: "prod.example.com", username: "deploy")
        ],
        onImport: { _ in },
        onClose: {}
    )
    .padding()
}
