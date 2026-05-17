import Foundation

// MARK: - TerminalController SFTP 面板管理

extension TerminalController {

    /// 打开 SFTP 面板（建立独立 SFTP 连接）
    func openSFTPPanel() async throws {
        guard state == .connected else { throw SSHError.sessionClosed }
        guard sftpSession == nil else {
            isSFTPPanelOpen = true
            return
        }

        let password   = try? await CredentialVault.shared.load(sessionId: session.id, type: .password)
        let passphrase = try? await CredentialVault.shared.load(sessionId: session.id, type: .passphrase)

        let newSFTPSession = SFTPSession()
        try await newSFTPSession.connect(
            host: session.host,
            port: session.port,
            username: session.username,
            authMethod: session.authMethod,
            password: password,
            privateKeyPath: session.privateKeyPath,
            passphrase: passphrase
        )

        sftpSession = newSFTPSession
        sftpTransferQueue = SFTPTransferQueue(sftpSession: newSFTPSession)
        isSFTPPanelOpen = true
        AppLogger.general.debug("[TerminalController] SFTP 面板已打开")
    }

    /// 关闭 SFTP 面板
    func closeSFTPPanel() async {
        if let s = sftpSession { await s.disconnect() }
        sftpSession = nil
        sftpTransferQueue = nil
        isSFTPPanelOpen = false
    }
}
