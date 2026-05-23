import SwiftUI
import UniformTypeIdentifiers

// MARK: - 导入/导出弹窗（Figma-Spec-v2 §14 §3）

/// 对齐 Figma-Spec-v2 §14 更新：
///   导出 Tab → 只读 JSON Textarea + 复制/下载按钮
///   导入 Tab → 可编辑粘贴区 + 选择文件按钮
///   弹窗宽度 600pt
struct SessionImportExportView: View {

    // MARK: - 属性

    let sessions: [Session]
    var onImport: ([Session]) -> Void
    var onClose: () -> Void

    // MARK: - 状态

    @State private var activeTab: ExportTab = .export

    /// 导出 Tab：生成好的 JSON 预览文本（只读）
    @State private var exportJSONPreview: String = ""
    /// 导入 Tab：用户粘贴的文本内容
    @State private var importPasteText: String = ""
    @State private var importError: String?

    enum ExportTab: String, CaseIterable {
        case export = "导出"
        case `import` = "导入"
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
        .frame(width: 600)
        .frame(minHeight: 380, maxHeight: 560)
        .background {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(DesignTokens.Colors.surfaceCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
        .onAppear {
            generateExportPreview()
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
                    .font(DesignTokens.Typography.labelLargeMid)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.px) {
                Text("导入 / 导出")
                    .font(DesignTokens.Typography.bodyLargeStrong)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("备份、恢复或迁移会话配置（不含凭据）")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

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

    // MARK: - Tab 选择器

    private var tabPickerView: some View {
        HStack(spacing: DesignTokens.Spacing.xxxs) {
            ForEach(ExportTab.allCases, id: \.rawValue) { tab in
                Button(action: { activeTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: activeTab == tab ? .semibold : .regular))
                        .foregroundColor(activeTab == tab
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(activeTab == tab ? DesignTokens.Colors.surfaceActive : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: activeTab == tab ? Color.black.opacity(0.08) : .clear,
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

    // MARK: - 导出 Tab（只读 JSON Textarea + 复制 + 下载）

    private var exportTabContent: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 只读 JSON 预览区
            ScrollView {
                Text(exportJSONPreview.isEmpty ? "（无会话可导出）" : exportJSONPreview)
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(exportJSONPreview.isEmpty
                        ? DesignTokens.Colors.textTertiary
                        : DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.sm)
            }
            .frame(height: 220)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )

            // 操作按钮行
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportJSONPreview, forType: .string)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(DesignTokens.Typography.labelMedium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(exportJSONPreview.isEmpty)

                Button {
                    exportAsJSON(sessions)
                } label: {
                    Label("下载文件", systemImage: "arrow.down.circle")
                        .font(DesignTokens.Typography.labelMedium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(sessions.isEmpty)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - 导入 Tab（粘贴文本区 + 文件选择按钮）

    private var importTabContent: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 可编辑粘贴区
            ZStack(alignment: .topLeading) {
                TextEditor(text: $importPasteText)
                    .font(DesignTokens.Typography.codeTiny)
                    .frame(height: 180)
                    .scrollContentBackground(.hidden)
                    .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
                    )

                if importPasteText.isEmpty {
                    Text("在此粘贴 JSON 内容…")
                        .font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                }
            }

            // 按钮行
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    let trimmed = importPasteText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty,
                          let data = trimmed.data(using: .utf8) else {
                        importError = "请先粘贴有效的 JSON 内容"
                        return
                    }
                    importError = nil
                    processImportData(data, fileExtension: "json")
                } label: {
                    Label("导入粘贴内容", systemImage: "arrow.down.doc")
                        .font(DesignTokens.Typography.labelMedium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(importPasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    pickImportFile()
                } label: {
                    Label("选择文件…", systemImage: "folder")
                        .font(DesignTokens.Typography.labelMedium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // 支持格式提示
            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach([".json", ".xsh", ".ini", ".reg"], id: \.self) { fmt in
                    Text(fmt)
                        .font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, DesignTokens.Spacing.xxxs)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXXSmall, style: .continuous))
                }
                Spacer()
            }

            if let error = importError {
                Text(error)
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - 底部

    private var footerView: some View {
        HStack {
            Spacer()
            Button("关闭", action: onClose)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - 导出预览生成

    /// 将所有会话序列化为 JSON 字符串，显示在只读预览区
    private func generateExportPreview() {
        struct SessionExport: Encodable {
            let version: Int
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
            version: 1,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            sessions: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(export),
           let text = String(data: data, encoding: .utf8) {
            exportJSONPreview = text
        }
    }

    // MARK: - 导出逻辑（NSSavePanel）

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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(export) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "shellmate-sessions-\(datePrefix()).json"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - 导入逻辑（NSOpenPanel / 粘贴解析）

    private func pickImportFile() {
        importError = nil
        let panel = NSOpenPanel()
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

            let imported = export.sessions.map { record -> Session in
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
            onImport(imported)
            onClose()
            return
        }

        // 竞品格式：Xshell / SecureCRT / PuTTY
        do {
            let imported = try SessionFormatParser.parse(data: data, fileExtension: ext)
            onImport(imported)
            onClose()
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - 辅助

    private func datePrefix() -> String {
        String(ISO8601DateFormatter().string(from: Date()).prefix(10))
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
