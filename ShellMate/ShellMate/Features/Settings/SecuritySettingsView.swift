import SwiftUI

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
    /// 是否显示修改主密码 Sheet
    @State private var showMasterPasswordSheet: Bool = false
    /// Known Hosts 悬停行 ID
    @State private var hoveredKHId: UUID? = nil
    /// 导入私钥错误提示
    @State private var showImportError: Bool = false
    @State private var importErrorMessage: String = ""

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 主密码 Section
                masterPasswordSection

                Divider().padding(.vertical, DesignTokens.Spacing.md)

                // Known Hosts Section
                knownHostsSection

                Divider().padding(.vertical, DesignTokens.Spacing.md)

                // SSH 密钥管理 Section
                sshKeysSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
        .sheet(isPresented: $showKeyGenSheet) {
            KeyGenSheet(isPresented: $showKeyGenSheet)
        }
        .sheet(isPresented: $showMasterPasswordSheet) {
            MasterPasswordSheet(isPresented: $showMasterPasswordSheet)
        }
        .alert("导入失败", isPresented: $showImportError) {
            Button("好") {}
        } message: {
            Text(importErrorMessage)
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
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 启用开关
            HStack {
                Text("启用主密码（应用启动时要求验证）")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $store.masterPasswordEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            // 自动锁定
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("自动锁定")
                    .font(DesignTokens.Typography.captionLarge)
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
                showMasterPasswordSheet = true
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
                    .font(DesignTokens.Typography.labelMedium)
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
            .font(DesignTokens.Typography.captionMedium)
            .foregroundColor(DesignTokens.Colors.textTertiary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(DesignTokens.Colors.surfacePanel)

            Divider()

            if store.knownHosts.isEmpty {
                // 空状态
                VStack(spacing: DesignTokens.Spacing.md) {
                    AppIcon.serverRack.image
                        .font(DesignTokens.Typography.displayLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .opacity(0.4)
                    Text("尚无已记录的服务器指纹")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xxl)
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
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
    }

    @ViewBuilder
    private func knownHostRow(_ entry: KnownHostEntry) -> some View {
        let dateStr = dateFormatter.string(from: entry.addedAt)
        HStack(spacing: 0) {
            Text(entry.hostIdentifier)
                .font(DesignTokens.Typography.codeTiny)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.keyType)
                .font(DesignTokens.Typography.codeTiny)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 72, alignment: .leading)

            Text(dateStr)
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 88, alignment: .leading)

            // 状态
            Text("—")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 32, alignment: .center)

            // 删除按钮
            Button(action: { store.deleteKnownHost(entry) }) {
                AppIcon.trash.image
                    .font(DesignTokens.Typography.captionLarge)
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
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Button(action: { showKeyGenSheet = true }) {
                    Text("生成新密钥对…")
                        .font(DesignTokens.Typography.captionLarge)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button(action: importKey) {
                    Text("导入私钥…")
                        .font(DesignTokens.Typography.captionLarge)
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
            .font(DesignTokens.Typography.captionMedium)
            .foregroundColor(DesignTokens.Colors.textTertiary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(DesignTokens.Colors.surfacePanel)

            Divider()

            if store.sshKeys.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    AppIcon.key.image
                        .font(DesignTokens.Typography.displaySmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .opacity(0.4)
                    Text("尚无已存储的 SSH 私钥")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.xl)
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
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
    }

    private func sshKeyRow(_ key: SSHKeyRecord) -> some View {
        HStack(spacing: 0) {
            // 图标
            AppIcon.key.image
                .font(DesignTokens.Typography.bodyLarge)
                .foregroundColor(Color(red: 0.72, green: 0.53, blue: 0.04))
                .frame(width: 26)

            // 信息区
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.px) {
                Text(key.name)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(key.path)
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(key.keyType)
                .font(DesignTokens.Typography.codeTiny)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 80, alignment: .leading)

            Text("用于 \(key.linkedSessionCount) 个会话")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)

            HStack(spacing: DesignTokens.Spacing.xxs) {
                Button("查看") {}
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.mini)
                    .font(DesignTokens.Typography.captionSmall)

                Button(action: {}) {
                    AppIcon.trash.image
                        .font(DesignTokens.Typography.captionLarge)
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
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            performImport(from: url)
        }
    }

    private func performImport(from url: URL) {
        let fm = FileManager.default
        let sshDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        let destURL = sshDir.appendingPathComponent(url.lastPathComponent)

        // 沙盒安全作用域访问
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            // 校验是否为 PEM 格式私钥
            let content = try String(contentsOf: url, encoding: .utf8)
            guard content.contains("-----BEGIN ") else {
                importErrorMessage = "所选文件不是有效的 PEM 格式私钥，请重新选择。"
                showImportError = true
                return
            }

            // 确保 ~/.ssh 目录存在
            if !fm.fileExists(atPath: sshDir.path) {
                try fm.createDirectory(at: sshDir, withIntermediateDirectories: true, attributes: nil)
            }

            // 文件已在 ~/.ssh/ 目录内则无需复制，直接刷新
            if !fm.fileExists(atPath: destURL.path) {
                try fm.copyItem(at: url, to: destURL)
                // 设置私钥权限为 0600（owner read/write only）
                try fm.setAttributes([.posixPermissions: NSNumber(value: 0o600)],
                                     ofItemAtPath: destURL.path)
            }

            store.refresh()
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
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
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Button(action: { isPresented = false }) {
                    AppIcon.close.image
                        .font(DesignTokens.Typography.labelSmall)
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
            CustomTextField(placeholder: "用途注释，如 work-laptop-2026", text: $comment)

            // Passphrase
            CustomTextField(placeholder: "留空表示不设置 Passphrase", text: $passphrase, isSecure: true)

            if !passphrase.isEmpty {
                CustomTextField(placeholder: "确认 Passphrase", text: $passphraseConfirm, isSecure: true)
            }

            // 保存路径
            HStack(spacing: DesignTokens.Spacing.sm) {
                CustomTextField(placeholder: "", text: $savePath)
                    .font(DesignTokens.Typography.codeTiny)

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
        .padding(DesignTokens.Spacing.lg)
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
        Task { try? await Task.sleep(nanoseconds: 500_000_000); isGenerating = false; isPresented = false }
    }
}

// MARK: - 修改主密码 Sheet

/// 修改主密码弹窗
/// 验证旧密码后允许设置新密码，写入系统 Keychain（仅主密码本身）
struct MasterPasswordSheet: View {

    @Binding var isPresented: Bool

    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String = ""
    @State private var isFirstSetup: Bool = false

    private let keychainKey = "shellmate.masterPassword"
    private let keychainService = "com.shellmate.app"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text(isFirstSetup ? "设置主密码" : "修改主密码")
                    .font(DesignTokens.Typography.bodyLargeStrong)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Button(action: { isPresented = false }) {
                    AppIcon.close.image
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                // 说明
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    AppIcon.lockShield.image
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                    Text("主密码存储于本设备 Keychain，用于应用启动时身份验证。SSH 凭据使用 AES-256-GCM 加密存储于本地数据库，不参与 iCloud 同步。忘记主密码后需重置应用数据。")
                        .font(.system(size: 10.5))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.surfaceWindow)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))

                // 旧密码（首次设置时隐藏）
                if !isFirstSetup {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text("当前密码")
                            .font(DesignTokens.Typography.captionLarge)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                        CustomTextField(placeholder: "请输入当前主密码", text: $oldPassword, isSecure: true)
                            .font(DesignTokens.Typography.bodySmall)
                    }
                }

                // 新密码
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("新密码")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    CustomTextField(placeholder: "至少 8 位，建议包含大小写字母+数字", text: $newPassword, isSecure: true)
                        .font(DesignTokens.Typography.bodySmall)

                    // 密码强度指示器
                    if !newPassword.isEmpty {
                        passwordStrengthBar
                    }
                }

                // 确认新密码
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("确认新密码")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    CustomTextField(placeholder: "再次输入新密码", text: $confirmPassword, isSecure: true)
                        .font(DesignTokens.Typography.bodySmall)
                    // 不一致提示
                    if !confirmPassword.isEmpty && confirmPassword != newPassword {
                        Text("两次输入不一致")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.statusError)
                    }
                }

                // 错误信息
                if !errorMessage.isEmpty {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        AppIcon.feedbackWarn.image
                            .font(DesignTokens.Typography.captionLarge)
                        Text(errorMessage)
                            .font(DesignTokens.Typography.captionLarge)
                    }
                    .foregroundColor(DesignTokens.Colors.statusError)
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])

                Button(isFirstSetup ? "设置" : "修改") {
                    saveMasterPassword()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(newPassword.count < 8 || confirmPassword.isEmpty)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 400)
        .background(DesignTokens.Colors.surfacePanel)
        .onAppear { checkFirstSetup() }
    }

    // MARK: - 密码强度

    /// 密码强度（0-4）
    private var passwordStrength: Int {
        var score = 0
        if newPassword.count >= 8  { score += 1 }
        if newPassword.count >= 12 { score += 1 }
        if newPassword.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if newPassword.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }
        return min(score, 4)
    }

    private var passwordStrengthLabel: String {
        switch passwordStrength {
        case 0, 1: return "弱"
        case 2:    return "一般"
        case 3:    return "较强"
        default:   return "强"
        }
    }

    private var passwordStrengthColor: Color {
        switch passwordStrength {
        case 0, 1: return DesignTokens.Colors.statusError
        case 2:    return DesignTokens.Colors.statusConnecting
        case 3:    return DesignTokens.Colors.statusConnecting
        default:   return DesignTokens.Colors.statusConnected
        }
    }

    private var passwordStrengthBar: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < passwordStrength
                          ? passwordStrengthColor
                          : DesignTokens.Colors.borderSecondary)
                    .frame(height: 3)
            }
            Text(passwordStrengthLabel)
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(passwordStrengthColor)
        }
    }

    private func checkFirstSetup() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: false
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        isFirstSetup = (status == errSecItemNotFound)
    }

    private func saveMasterPassword() {
        errorMessage = ""

        // 验证新密码：长度 + 必须包含字母 + 数字（复杂度最低要求）
        guard newPassword.count >= 8 else {
            errorMessage = "新密码至少需要 8 位"; return
        }
        guard newPassword.range(of: "[A-Za-z]", options: .regularExpression) != nil else {
            errorMessage = "新密码必须包含至少一个字母"; return
        }
        guard newPassword.range(of: "[0-9]", options: .regularExpression) != nil else {
            errorMessage = "新密码必须包含至少一个数字"; return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"; return
        }

        // 验证旧密码（非首次设置）
        if !isFirstSetup {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainKey,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess,
                  let data = result as? Data,
                  let stored = String(data: data, encoding: .utf8),
                  stored == oldPassword else {
                errorMessage = "当前密码错误"; return
            }
            // 删除旧条目
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainKey
            ]
            SecItemDelete(deleteQuery as CFDictionary)
        }

        // 写入新密码
        let newData = Data(newPassword.utf8)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: newData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            isPresented = false
        } else {
            errorMessage = "主密码写入失败（错误码：\(addStatus)）"
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

#Preview("修改主密码") {
    MasterPasswordSheet(isPresented: .constant(true))
}
