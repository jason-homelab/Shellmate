import Foundation

// MARK: - SSH Config 解析结果

/// 从 ~/.ssh/config 解析得到的单个主机条目
struct SSHConfigEntry: Identifiable {
    let id = UUID()
    /// Host 关键字（可含通配符，如 "bastion-*"）
    let hostPattern: String
    /// 实际主机名（HostName 字段，若缺省则与 hostPattern 相同）
    let hostname: String
    /// 端口（Port 字段，默认 22）
    let port: Int32
    /// 用户名（User 字段）
    let username: String
    /// 私钥文件路径（IdentityFile 字段，展开 ~ 路径）
    let identityFile: String?
    /// 跳板机（ProxyJump 字段）
    let proxyJump: String?

    /// 是否为通配符条目（含 * 或 ?，不适合直接导入）
    var isWildcard: Bool {
        hostPattern.contains("*") || hostPattern.contains("?")
    }

    /// 转换为 Session 业务模型
    func toSession() -> Session {
        let authMethod: AuthMethod = identityFile != nil ? .privateKey : .password
        return Session(
            name: hostPattern,
            host: hostname,
            port: port,
            username: username.isEmpty ? "root" : username,
            authMethod: authMethod,
            privateKeyPath: identityFile,
            proxyJumpString: proxyJump
        )
    }
}

// MARK: - SSH Config 解析器

/// 解析 OpenSSH ~/.ssh/config 格式
/// 支持：Host、HostName、Port、User、IdentityFile、ProxyJump、ProxyCommand
enum SSHConfigParser {

    /// 解析指定路径的 SSH 配置文件
    /// - Parameter url: 配置文件 URL（默认为 ~/.ssh/config）
    /// - Returns: 解析得到的条目列表（不含通配符条目 `Host *`）
    static func parse(url: URL? = nil) throws -> [SSHConfigEntry] {
        let configURL = url ?? defaultConfigURL
        let content = try String(contentsOf: configURL, encoding: .utf8)
        return parseContent(content)
    }

    /// 解析 SSH 配置文件内容字符串（方便测试）
    static func parseContent(_ content: String) -> [SSHConfigEntry] {
        var entries: [SSHConfigEntry] = []

        // 按 Host 关键字分组
        var currentHost: String?
        var currentHostname: String?
        var currentPort: Int32 = 22
        var currentUser: String = ""
        var currentIdentityFile: String?
        var currentProxyJump: String?

        func flushCurrent() {
            guard let host = currentHost else { return }
            let hostname = currentHostname ?? host
            entries.append(SSHConfigEntry(
                hostPattern: host,
                hostname: hostname,
                port: currentPort,
                username: currentUser,
                identityFile: currentIdentityFile,
                proxyJump: currentProxyJump
            ))
        }

        let lines = content.components(separatedBy: .newlines)
        for rawLine in lines {
            // 去掉注释和空行
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            // 解析 keyword value（支持空格或 = 分隔）
            let (keyword, value) = splitKeyValue(line)
            guard !keyword.isEmpty, !value.isEmpty else { continue }

            switch keyword.lowercased() {
            case "host":
                // 遇到新的 Host 块时，先保存上一个
                flushCurrent()
                currentHost = value
                currentHostname = nil
                currentPort = 22
                currentUser = ""
                currentIdentityFile = nil
                currentProxyJump = nil

            case "hostname":
                currentHostname = value

            case "port":
                currentPort = Int32(value) ?? 22

            case "user":
                currentUser = value

            case "identityfile":
                currentIdentityFile = expandTilde(value)

            case "proxyjump":
                currentProxyJump = value

            case "proxycommand":
                // ProxyCommand 中常见 "ssh -W %h:%p bastion" 模式，尝试提取跳板机
                if currentProxyJump == nil {
                    currentProxyJump = extractProxyJumpFromCommand(value)
                }

            default:
                break
            }
        }

        // 保存最后一个条目
        flushCurrent()

        // 过滤掉纯通配符的 "Host *" 全局默认块
        return entries.filter { $0.hostPattern != "*" }
    }

    // MARK: - 私有辅助

    static var defaultConfigURL: URL {
        URL(fileURLWithPath: NSString("~/.ssh/config").expandingTildeInPath)
    }

    /// 检查 ~/.ssh/config 文件是否存在
    static var configFileExists: Bool {
        FileManager.default.fileExists(atPath: defaultConfigURL.path)
    }

    /// 将 "keyword value" 或 "keyword=value" 拆分为 (keyword, value)
    private static func splitKeyValue(_ line: String) -> (String, String) {
        // 先尝试 = 分隔
        if let eqRange = line.range(of: "=") {
            let k = String(line[line.startIndex..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let v = String(line[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (k, v)
        }
        // 空格分隔
        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 2 else { return (parts.first ?? "", "") }
        return (parts[0], parts.dropFirst().joined(separator: " "))
    }

    /// 展开 ~ 路径
    private static func expandTilde(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    /// 从 ProxyCommand 中提取跳板机地址（"ssh -W %h:%p user@bastion" → "user@bastion"）
    private static func extractProxyJumpFromCommand(_ cmd: String) -> String? {
        let parts = cmd.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // 找最后一个不以 - 开头且不含 %h / %p 的参数
        for part in parts.reversed() {
            if !part.hasPrefix("-") && !part.contains("%") && part != "ssh" && part != "nc" {
                return part
            }
        }
        return nil
    }
}
