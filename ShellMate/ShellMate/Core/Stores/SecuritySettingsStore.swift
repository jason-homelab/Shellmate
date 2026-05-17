import SwiftUI

// MARK: - SSH 密钥模型

/// SSH 私钥记录（UI 展示用，私钥存储于文件系统或凭据金库）
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

    @AppStorage("security.masterPasswordEnabled") var masterPasswordEnabled: Bool = false
    @AppStorage("security.autoLockMinutes") var autoLockMinutes: Int = 0

    @Published var knownHosts: [KnownHostEntry] = []
    @Published var sshKeys: [SSHKeyRecord] = []

    private init() {
        refresh()
    }

    func refresh() {
        knownHosts = KnownHostsManager.shared.getAll()
        sshKeys = Self.scanSSHKeys()
    }

    private static func scanSSHKeys() -> [SSHKeyRecord] {
        let sshDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: sshDir, includingPropertiesForKeys: nil
        ) else { return [] }

        return contents.compactMap { url -> SSHKeyRecord? in
            let name = url.lastPathComponent
            guard !name.hasSuffix(".pub"),
                  !name.hasSuffix(".old"),
                  name != "known_hosts",
                  name != "known_hosts.old",
                  name != "config",
                  name != "authorized_keys",
                  !name.hasPrefix(".") else { return nil }

            guard let firstLine = (try? String(contentsOf: url, encoding: .utf8))?
                    .components(separatedBy: "\n").first else { return nil }
            guard firstLine.hasPrefix("-----BEGIN ") else { return nil }

            let keyType: String
            if firstLine.contains("ED25519")       { keyType = "Ed25519" }
            else if firstLine.contains("ECDSA")    { keyType = "ECDSA" }
            else if firstLine.contains("RSA")      { keyType = "RSA" }
            else if firstLine.contains("DSA")      { keyType = "DSA" }
            else if firstLine.contains("OPENSSH")  { keyType = "OpenSSH" }
            else                                   { keyType = "Unknown" }

            let displayPath = url.path.replacingOccurrences(
                of: FileManager.default.homeDirectoryForCurrentUser.path,
                with: "~"
            )
            return SSHKeyRecord(
                id: UUID(),
                name: name,
                path: displayPath,
                keyType: keyType,
                linkedSessionCount: 0
            )
        }.sorted { $0.name < $1.name }
    }

    func deleteKnownHost(_ entry: KnownHostEntry) {
        try? KnownHostsManager.shared.remove(entry: entry)
        refresh()
    }

    func clearAllKnownHosts() {
        try? KnownHostsManager.shared.clear()
        refresh()
    }
}
