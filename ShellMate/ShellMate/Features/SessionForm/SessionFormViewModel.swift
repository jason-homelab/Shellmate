import SwiftUI

/// 会话表单 ViewModel
/// 集中管理 SessionFormSheet 的全部可变状态和业务逻辑。
/// View 层只负责布局，不再持有 @State 业务变量。
@MainActor
final class SessionFormViewModel: ObservableObject {

    // MARK: - 配置（初始化后不变）

    let editingSession: Session?
    let defaultGroupId: UUID?
    let groups: [SessionGroup]
    var onSave: ((Session) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - 基本信息

    @Published var name: String = ""
    @Published var host: String = ""
    @Published var port: String = "22"
    @Published var username: String = ""
    @Published var selectedGroupId: UUID?
    @Published var connectionProtocol: String = "SSH"

    // MARK: - 认证信息

    @Published var authMethod: AuthMethod = .password
    @Published var privateKeyPath: String = ""
    @Published var password: String = ""
    @Published var passphrase: String = ""
    @Published var saveCredential: Bool = true

    // MARK: - 高级设置

    @Published var keepAliveInterval: Int32 = 60
    @Published var autoReconnect: Bool = true
    @Published var encoding: String = "UTF-8"
    @Published var proxyJump: String = ""
    @Published var connectTimeout: Int32 = 30
    @Published var maxReconnectRetries: Int32 = 3
    @Published var reconnectInterval: Int32 = 5
    @Published var envVarEntries: [EnvVarEntry] = []
    @Published var tmuxConfig: TmuxConfig = TmuxConfig()
    @Published var colorHex: String = "#4A90D9"
    @Published var tags: [String] = []
    @Published var overrideThemeId: String = ""
    @Published var overrideFontSizeValue: Int32 = 0
    @Published var startupCommand: String = ""

    // MARK: - 串口设置

    @Published var serialPortPath: String = ""
    @Published var serialBaudRate: Int32 = 9600
    @Published var serialDataBits: Int32 = 8
    @Published var serialParity: String = "none"
    @Published var serialStopBits: Int32 = 1
    @Published var serialFlowControl: String = "none"
    @Published var availableSerialPorts: [String] = []

    // MARK: - UI 状态

    @Published var validationErrors: [String] = []
    @Published var advancedExpanded: Bool = false

    // MARK: - 计算属性

    var isEditing: Bool { editingSession != nil }
    var title: String { isEditing ? "编辑会话" : "新建会话" }

    var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch connectionProtocol {
        case "Serial":
            return !serialPortPath.isEmpty
        case "Telnet":
            return !host.trimmingCharacters(in: .whitespaces).isEmpty && Int32(port) != nil
        default:
            return !host.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !username.trimmingCharacters(in: .whitespaces).isEmpty &&
                   Int32(port) != nil
        }
    }

    var resolvedConnectionType: ConnectionType {
        switch connectionProtocol {
        case "Telnet": return .telnet
        case "Serial": return .serial
        default: return .ssh
        }
    }

    // MARK: - 初始化

    init(
        editingSession: Session? = nil,
        defaultGroupId: UUID? = nil,
        groups: [SessionGroup] = [],
        onSave: ((Session) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.editingSession = editingSession
        self.defaultGroupId = defaultGroupId
        self.groups = groups
        self.onSave = onSave
        self.onCancel = onCancel
    }

    // MARK: - 生命周期

    /// onAppear 时调用：加载数据并应用默认协议（仅新建时）
    func configure(defaultProtocol: String) {
        loadSessionData()
        if editingSession == nil {
            connectionProtocol = defaultProtocol
            if let gid = defaultGroupId { selectedGroupId = gid }
        }
    }

    // MARK: - 协议切换

    func handleProtocolChange(_ newValue: String) {
        switch newValue {
        case "Telnet":
            if port == "22" || port.isEmpty { port = "23" }
        case "Serial":
            refreshSerialPorts()
        default:
            if port == "23" || port.isEmpty { port = "22" }
        }
    }

    func refreshSerialPorts() {
        availableSerialPorts = SerialPortScanner.availablePorts()
        if serialPortPath.isEmpty, let first = availableSerialPorts.first {
            serialPortPath = first
        }
    }

    // MARK: - 操作

    func cancel() { onCancel?() }

    func save() {
        validationErrors = []
        let connType = resolvedConnectionType

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("请输入会话名称")
        }

        var portNumber: Int32 = 0
        if connType == .serial {
            if serialPortPath.isEmpty {
                validationErrors.append("请选择串口设备")
            }
        } else {
            if host.trimmingCharacters(in: .whitespaces).isEmpty {
                validationErrors.append("请输入主机地址")
            }
            if connType == .ssh && username.trimmingCharacters(in: .whitespaces).isEmpty {
                validationErrors.append("请输入用户名")
            }
            guard let p = Int32(port), p > 0, p <= 65535 else {
                validationErrors.append("请输入有效的端口号 (1-65535)")
                return
            }
            portNumber = p
        }

        if !validationErrors.isEmpty { return }

        let envVars = Dictionary(
            envVarEntries
                .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { ($0.key.trimmingCharacters(in: .whitespaces), $0.value) },
            uniquingKeysWith: { _, last in last }
        )

        let session: Session
        if let existing = editingSession {
            session = Session(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                host: host.trimmingCharacters(in: .whitespaces),
                port: portNumber,
                username: username.trimmingCharacters(in: .whitespaces),
                authMethod: authMethod,
                keychainRef: existing.keychainRef,
                privateKeyPath: privateKeyPath.isEmpty ? nil : privateKeyPath,
                keepAliveInterval: keepAliveInterval,
                autoReconnect: autoReconnect,
                encoding: encoding,
                tags: tags,
                sortOrder: existing.sortOrder,
                colorHex: colorHex,
                lastConnectedAt: existing.lastConnectedAt,
                createdAt: existing.createdAt,
                modifiedAt: Date(),
                isSoftDeleted: false,
                groupId: selectedGroupId,
                proxyJumpString: proxyJump.isEmpty ? nil : proxyJump,
                connectTimeout: connectTimeout,
                maxReconnectRetries: maxReconnectRetries,
                reconnectInterval: reconnectInterval,
                envVars: envVars,
                startupCommand: startupCommand.isEmpty ? nil : startupCommand,
                overrideThemeId: overrideThemeId.isEmpty ? nil : overrideThemeId,
                overrideFontSize: overrideFontSizeValue,
                connectionType: connType,
                serialPortPath: serialPortPath.isEmpty ? nil : serialPortPath,
                serialBaudRate: serialBaudRate,
                serialDataBits: serialDataBits,
                serialParity: serialParity,
                serialStopBits: serialStopBits,
                serialFlowControl: serialFlowControl
            )
        } else {
            session = Session(
                name: name.trimmingCharacters(in: .whitespaces),
                host: host.trimmingCharacters(in: .whitespaces),
                port: portNumber,
                username: username.trimmingCharacters(in: .whitespaces),
                authMethod: authMethod,
                privateKeyPath: privateKeyPath.isEmpty ? nil : privateKeyPath,
                keepAliveInterval: keepAliveInterval,
                autoReconnect: autoReconnect,
                encoding: encoding,
                tags: tags,
                colorHex: colorHex,
                groupId: selectedGroupId,
                proxyJumpString: proxyJump.isEmpty ? nil : proxyJump,
                connectTimeout: connectTimeout,
                maxReconnectRetries: maxReconnectRetries,
                reconnectInterval: reconnectInterval,
                envVars: envVars,
                startupCommand: startupCommand.isEmpty ? nil : startupCommand,
                overrideThemeId: overrideThemeId.isEmpty ? nil : overrideThemeId,
                overrideFontSize: overrideFontSizeValue,
                connectionType: connType,
                serialPortPath: serialPortPath.isEmpty ? nil : serialPortPath,
                serialBaudRate: serialBaudRate,
                serialDataBits: serialDataBits,
                serialParity: serialParity,
                serialStopBits: serialStopBits,
                serialFlowControl: serialFlowControl
            )
        }

        TmuxConfigStore.save(tmuxConfig, sessionId: session.id)
        saveCredentials(for: session)
        onSave?(session)
    }

    // MARK: - 数据加载

    private func loadSessionData() {
        guard let session = editingSession else { return }

        name = session.name
        host = session.host
        port = String(session.port)
        username = session.username
        selectedGroupId = session.groupId
        authMethod = session.authMethod
        privateKeyPath = session.privateKeyPath ?? ""
        keepAliveInterval = session.keepAliveInterval
        autoReconnect = session.autoReconnect
        encoding = session.encoding
        colorHex = session.colorHex ?? "#4A90D9"
        tags = session.tags
        proxyJump = session.proxyJumpString ?? ""
        connectTimeout = session.connectTimeout
        maxReconnectRetries = session.maxReconnectRetries
        reconnectInterval = session.reconnectInterval
        envVarEntries = session.envVars.map { EnvVarEntry(key: $0.key, value: $0.value) }
        startupCommand = session.startupCommand ?? ""
        overrideThemeId = session.overrideThemeId ?? ""
        overrideFontSizeValue = session.overrideFontSize
        tmuxConfig = TmuxConfigStore.load(sessionId: session.id)

        switch session.connectionType {
        case .telnet: connectionProtocol = "Telnet"
        case .serial: connectionProtocol = "Serial"
        default: connectionProtocol = "SSH"
        }

        serialBaudRate = session.serialBaudRate
        serialDataBits = session.serialDataBits
        serialParity = session.serialParity
        serialStopBits = session.serialStopBits
        serialFlowControl = session.serialFlowControl
        if session.connectionType == .serial {
            availableSerialPorts = SerialPortScanner.availablePorts()
            serialPortPath = session.serialPortPath ?? availableSerialPorts.first ?? ""
        } else {
            serialPortPath = session.serialPortPath ?? ""
        }

        // 编辑时不回显已存储的密码
        password = ""
        passphrase = ""
    }

    // MARK: - 凭据保存

    private func saveCredentials(for session: Session) {
        guard saveCredential else { return }
        let pwd = password
        let pp = passphrase
        password.removeAll(keepingCapacity: false)
        passphrase.removeAll(keepingCapacity: false)
        Task {
            do {
                if !pwd.isEmpty {
                    try await CredentialVault.shared.save(pwd, sessionId: session.id, type: .password)
                }
                if !pp.isEmpty {
                    try await CredentialVault.shared.save(pp, sessionId: session.id, type: .passphrase)
                }
            } catch {
                AppLogger.ui.debug("[SessionFormViewModel] 凭据保存失败: \(error.localizedDescription)")
            }
        }
    }
}
