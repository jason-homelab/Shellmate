import SwiftUI

// MARK: - SSH 密钥模型

/// 存储在 Keychain/文件系统中的 SSH 私钥记录（UI 展示用）
struct SSHKeyRecord: Identifiable {
    let id: UUID
    let name: String
    let path: String
    let keyType: String
    let linkedSessionCount: Int

    static let examples: [SSHKeyRecord] = [
        SSHKeyRecord(id: UUID(), name: "id_ed25519",   path: "~/.ssh/id_ed25519",   keyType: "Ed25519",  linkedSessionCount: 2),
        SSHKeyRecord(id: UUID(), name: "id_rsa_work",  path: "~/.ssh/id_rsa_work",  keyType: "RSA-4096", linkedSessionCount: 1),
    ]
}

// MARK: - 安全设置 Store

/// S03 安全设置数据层（@AppStorage + KnownHostsManager 桥接）
@MainActor
final class SecuritySettingsStore: ObservableObject {

    static let shared = SecuritySettingsStore()

    /// 是否启用主密码
    @AppStorage("security.masterPasswordEnabled") var masterPasswordEnabled: Bool = false
    /// 自动锁定间隔（分钟，0=不锁定）
    @AppStorage("security.autoLockMinutes") var autoLockMinutes: Int = 0

    /// Known Hosts 列表（从 KnownHostsManager 加载）
    @Published var knownHosts: [KnownHostEntry] = []

    /// SSH 密钥列表（占位，实际来自文件系统扫描）
    @Published var sshKeys: [SSHKeyRecord] = []

    private init() {
        refresh()
    }

    /// 刷新数据
    func refresh() {
        knownHosts = KnownHostsManager.shared.getAll()
        sshKeys = SSHKeyRecord.examples  // W14: 替换为真实文件系统扫描
    }

    /// 删除 Known Host 条目
    func deleteKnownHost(_ entry: KnownHostEntry) {
        try? KnownHostsManager.shared.remove(entry: entry)
        refresh()
    }

    /// 清除所有 Known Hosts
    func clearAllKnownHosts() {
        try? KnownHostsManager.shared.clear()
        refresh()
    }
}

// MARK: - 安全设置视图

/// S03 — 安全与凭据管理设置面板
struct SecuritySettingsView: View {

    // MARK: - 依赖

    @ObservedObject private var store = SecuritySettingsStore.shared

    // MARK: - 状态

    /// 是否显示生成密钥对 Sheet
    @State private var showKeyGenSheet: Bool = false
    /// 是否显示清除确认 Alert
    @State private var showClearConfirm: Bool = false
    /// Known Hosts 悬停行 ID
    @State private var hoveredKHId: UUID? = nil

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 主密码 Section
                masterPasswordSection

                Divider().padding(.vertical, 12)

                // Known Hosts Section
                knownHostsSection

                Divider().padding(.vertical, 12)

                // SSH 密钥管理 Section
                sshKeysSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showKeyGenSheet) {
            KeyGenSheet(isPresented: $showKeyGenSheet)
        }
        .alert("清除所有已信任指纹", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("全部清除", role: .destructive) {
                store.clearAllKnownHosts()
            }
        } message: {
            Text("此操作将删除所有已记录的服务器指纹，下次连接时需要重新确认。")
        }
    }

    // MARK: - 主密码 Section

    private var masterPasswordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("主密码")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 启用开关
            Toggle(isOn: $store.masterPasswordEnabled) {
                Text("启用主密码（应用启动时要求验证）")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .toggleStyle(.checkbox)

            // 自动锁定
            HStack(spacing: 8) {
                Text("自动锁定")
                    .font(.system(size: 11))
                    .foregroundColor(store.masterPasswordEnabled
                        ? DesignTokens.Colors.textSecondary
                        : DesignTokens.Colors.textTertiary)

                Picker("", selection: $store.autoLockMinutes) {
                    Text("不锁定").tag(0)
                    Text("1 分钟").tag(1)
                    Text("5 分钟").tag(5)
                    Text("15 分钟").tag(15)
                    Text("30 分钟").tag(30)
                    Text("1 小时").tag(60)
                }
                .labelsHidden()
                .frame(width: 140)
                .disabled(!store.masterPasswordEnabled)
            }

            // 修改主密码按钮
            Button("修改主密码…") {
                // W14: 打开修改主密码 Sheet
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.small)
            .disabled(!store.masterPasswordEnabled)
        }
    }

    // MARK: - Known Hosts Section

    private var knownHostsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack {
                Text("Known Hosts（已信任服务器指纹）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Button(action: { showClearConfirm = true }) {
                    Text("全部清除")
                        .font(.system(size: 10.5))
                        .foregroundColor(DesignTokens.Colors.statusError)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
                .disabled(store.knownHosts.isEmpty)
            }

            // 表格
            knownHostsTable
        }
    }

    private var knownHostsTable: some View {
        VStack(spacing: 0) {
            // 表头
            HStack(spacing: 0) {
                Text("主机名 / IP")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("密钥类型")
                    .frame(width: 72, alignment: .leading)
                Text("添加日期")
                    .frame(width: 88, alignment: .leading)
                Text("状态")
                    .frame(width: 32, alignment: .center)
                Text("操作")
                    .frame(width: 56, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(DesignTokens.Colors.textTertiary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(DesignTokens.Colors.surfacePanel)

            Divider()

            if store.knownHosts.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 28))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .opacity(0.4)
                    Text("尚无已记录的服务器指纹")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(store.knownHosts) { entry in
                    knownHostRow(entry)
                    if entry.id != store.knownHosts.last?.id {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
        .background(DesignTokens.Colors.surfaceWindow)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    @ViewBuilder
    private func knownHostRow(_ entry: KnownHostEntry) -> some View {
        let dateStr = dateFormatter.string(from: entry.addedAt)
        HStack(spacing: 0) {
            Text(entry.hostIdentifier)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.keyType)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 72, alignment: .leading)

            Text(dateStr)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 88, alignment: .leading)

            // 状态
            Text("—")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 32, alignment: .center)

            // 删除按钮
            Button(action: { store.deleteKnownHost(entry) }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(hoveredKHId == entry.id
                        ? DesignTokens.Colors.statusError
                        : DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .frame(width: 56, alignment: .trailing)
            .opacity(hoveredKHId == entry.id ? 1 : 0.4)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(hoveredKHId == entry.id ? DesignTokens.Colors.surfacePanel : Color.clear)
        .onHover { hovering in
            hoveredKHId = hovering ? entry.id : nil
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    // MARK: - SSH 密钥管理 Section

    private var sshKeysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            HStack {
                Text("SSH 密钥管理")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Button(action: { showKeyGenSheet = true }) {
                    Text("生成新密钥对…")
                        .font(.system(size: 11))
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button(action: importKey) {
                    Text("导入私钥…")
                        .font(.system(size: 11))
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }

            // 密钥列表
            sshKeysList
        }
    }

    private var sshKeysList: some View {
        VStack(spacing: 0) {
            // 表头
            HStack(spacing: 0) {
                Text("私钥标识符")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("类型")
                    .frame(width: 80, alignment: .leading)
                Text("关联会话")
                    .frame(width: 80, alignment: .leading)
                Text("操作")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(DesignTokens.Colors.textTertiary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(DesignTokens.Colors.surfacePanel)

            Divider()

            if store.sshKeys.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .opacity(0.4)
                    Text("尚无已存储的 SSH 私钥")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(store.sshKeys) { key in
                    sshKeyRow(key)
                    if key.id != store.sshKeys.last?.id {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
        .background(DesignTokens.Colors.surfaceWindow)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func sshKeyRow(_ key: SSHKeyRecord) -> some View {
        HStack(spacing: 0) {
            // 图标
            Image(systemName: "key.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.72, green: 0.53, blue: 0.04))
                .frame(width: 26)

            // 信息区
            VStack(alignment: .leading, spacing: 1) {
                Text(key.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(key.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(key.keyType)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 80, alignment: .leading)

            Text("用于 \(key.linkedSessionCount) 个会话")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)

            HStack(spacing: 4) {
                Button("查看") {}
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.mini)
                    .font(.system(size: 9.5))

                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
    }

    private func importKey() {
        let panel = NSOpenPanel()
        panel.title = "选择私钥文件"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            // W14: 导入私钥逻辑
            _ = url
        }
    }
}

// MARK: - 生成密钥对 Sheet

/// KeyGen Sheet — 从 Settings 窗口顶部滑出的密钥生成弹窗
struct KeyGenSheet: View {

    @Binding var isPresented: Bool

    @State private var algorithm: String = "Ed25519"
    @State private var comment: String = ""
    @State private var passphrase: String = ""
    @State private var passphraseConfirm: String = ""
    @State private var savePath: String = "~/.ssh/id_ed25519"
    @State private var isGenerating: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题行
            HStack {
                Text("生成新的 SSH 密钥对")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 算法
            Picker("算法", selection: $algorithm) {
                Text("Ed25519（推荐）").tag("Ed25519")
                Text("RSA-4096").tag("RSA-4096")
                Text("RSA-2048").tag("RSA-2048")
                Text("ECDSA-256").tag("ECDSA-256")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            // 注释
            TextField("用途注释，如 work-laptop-2026", text: $comment)
                .textFieldStyle(.roundedBorder)

            // Passphrase
            SecureField("留空表示不设置 Passphrase", text: $passphrase)
                .textFieldStyle(.roundedBorder)

            if !passphrase.isEmpty {
                SecureField("确认 Passphrase", text: $passphraseConfirm)
                    .textFieldStyle(.roundedBorder)
            }

            // 保存路径
            HStack(spacing: 8) {
                TextField("", text: $savePath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))

                Button("选择…") {
                    chooseSavePath()
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(BorderedButtonStyle())
                .keyboardShortcut(.cancelAction)

                Button(action: generateKey) {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                    } else {
                        Text("生成密钥对")
                    }
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(isGenerating || !isFormValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 440)
    }

    private var isFormValid: Bool {
        !passphrase.isEmpty ? passphrase == passphraseConfirm : true
    }

    private func chooseSavePath() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "id_\(algorithm.lowercased())"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            savePath = url.path
        }
    }

    private func generateKey() {
        isGenerating = true
        // W14: 实际密钥生成逻辑（libssh2 keygen）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isGenerating = false
            isPresented = false
        }
    }
}

// MARK: - 预览

#Preview("安全设置") {
    SecuritySettingsView()
        .frame(width: 480, height: 520)
        .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("生成密钥对") {
    KeyGenSheet(isPresented: .constant(true))
        .background(DesignTokens.Colors.surfaceWindow)
}
