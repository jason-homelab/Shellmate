import SwiftUI

// MARK: - ContentView 操作方法

extension ContentView {

    // MARK: - 导出会话（JSON，不含凭据）

    func exportSessions() {
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

        let exportedAt = ISO8601DateFormatter().string(from: Date())
        let records = sessionStore.sessions.map { s in
            SessionRecord(
                name: s.name, host: s.host, username: s.username, encoding: s.encoding,
                port: s.port, authMethodRaw: s.authMethod.rawValue,
                keepAliveInterval: s.keepAliveInterval, connectTimeout: s.connectTimeout,
                autoReconnect: s.autoReconnect, tags: s.tags,
                proxyJumpString: s.proxyJumpString, startupCommand: s.startupCommand
            )
        }
        let export = SessionExport(exportedAt: exportedAt, sessions: records)
        guard let data = try? JSONEncoder().encode(export) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "shellmate-sessions-\(ISO8601DateFormatter().string(from: Date()).prefix(10)).json"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - 导入会话

    func importSessions() {
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

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.prompt = "导入"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let export = try? JSONDecoder().decode(SessionExport.self, from: data)
        else { return }

        Task {
            for record in export.sessions {
                let authMethod = AuthMethod(rawValue: record.authMethodRaw) ?? .password
                let session = Session(
                    name: record.name, host: record.host, port: record.port,
                    username: record.username, authMethod: authMethod,
                    keepAliveInterval: record.keepAliveInterval, autoReconnect: record.autoReconnect,
                    encoding: record.encoding, tags: record.tags,
                    proxyJumpString: record.proxyJumpString, connectTimeout: record.connectTimeout,
                    startupCommand: record.startupCommand
                )
                await sessionStore.saveSession(session)
            }
        }
    }

    // MARK: - 设置面板（已迁移为自定义浮动面板，通过 panels.showSettingsPanel 控制）
    // 原 NSApp.sendAction(showSettingsWindow:) 已废弃，保留空函数避免调用侧编译错误
    func openNativeSettingsWindow() {}


    // MARK: - 连接方法

    func connectToSession(_ session: Session) {
        sessionStore.selectedSessionId = session.id

        // 如果该会话已有标签页，直接切换到它
        if let existingTab = tabBarStore.tab(for: session.id) {
            tabBarStore.selectTab(existingTab)
        } else {
            // 否则新建标签页
            tabBarStore.addTab(for: session)
        }

        // 更新最后连接时间
        Task {
            await sessionStore.updateLastConnectedAt(for: session.id)
        }
    }

    // MARK: - 新窗口自动连接

    /// 检查 UserDefaults 中是否有待自动连接的会话（由右键"在新窗口打开"写入）
    @MainActor
    func checkPendingAutoConnect() async {
        guard let idStr = UserDefaults.standard.string(forKey: "pendingAutoConnectSessionId"),
              let sessionId = UUID(uuidString: idStr) else { return }

        // 清除标记，防止重复触发
        UserDefaults.standard.removeObject(forKey: "pendingAutoConnectSessionId")

        // 等待 Core Data 会话加载（最多 1 秒，每 100ms 轮询一次）
        for _ in 0..<10 {
            if let session = sessionStore.sessions.first(where: { $0.id == sessionId }) {
                connectToSession(session)
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
