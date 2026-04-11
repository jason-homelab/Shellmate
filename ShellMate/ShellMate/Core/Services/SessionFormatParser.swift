import Foundation

// MARK: - 竞品会话格式解析器（任务 15.7）

/// 支持从 Xshell (.xsh)、SecureCRT (.ini)、PuTTY (.reg) 格式导入会话
/// 扩展自 12.9 导入能力，覆盖主流竞品会话格式
enum SessionFormatParser {

    // MARK: - 入口

    /// 根据文件扩展名自动选择解析器
    static func parse(data: Data, fileExtension: String) throws -> [Session] {
        switch fileExtension.lowercased() {
        case "xsh":   return try parseXshell(data: data)
        case "ini":   return try parseSecureCRT(data: data)
        case "reg":   return try parsePuTTY(data: data)
        default:      throw ParseError.unsupportedFormat(fileExtension)
        }
    }

    // MARK: - 错误类型

    enum ParseError: Error, LocalizedError {
        case unsupportedFormat(String)
        case emptyFile
        case invalidEncoding
        case noSessionsFound

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext):
                return "不支持的文件格式「.\(ext)」，支持：.xsh（Xshell）/ .ini（SecureCRT）/ .reg（PuTTY）"
            case .emptyFile:
                return "文件为空"
            case .invalidEncoding:
                return "无法读取文件内容，请确认文件编码为 UTF-8"
            case .noSessionsFound:
                return "文件中未找到有效的会话配置"
            }
        }
    }

    // MARK: - Xshell .xsh 解析器

    /// Xshell 会话文件（INI 风格）
    /// 支持 Xshell 5/6/7 格式
    ///
    /// ```
    /// [SessionInfo]
    /// Version=7.0
    /// [Connection]
    /// Host=192.168.1.1
    /// Port=22
    /// UserName=admin
    /// Protocol=SSH
    /// ```
    static func parseXshell(data: Data) throws -> [Session] {
        guard !data.isEmpty else { throw ParseError.emptyFile }
        guard let text = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1)
        else { throw ParseError.invalidEncoding }

        let dict = parseINI(text)

        // Xshell 只有单会话文件，从顶层或 [Connection] 段读
        let host = dict["connection.host"] ?? dict["host"] ?? ""
        guard !host.isEmpty else { throw ParseError.noSessionsFound }

        let portStr = dict["connection.port"] ?? dict["port"] ?? "22"
        let port = Int32(portStr) ?? 22
        let username = dict["connection.username"] ?? dict["username"] ?? ""

        // 会话名来自文件名（由调用方传入 fileName 最优，此处退用 host）
        let sessionName = dict["sessioninfo.sessionname"]
            ?? dict["sessionname"]
            ?? "\(username.isEmpty ? "" : username + "@")\(host)"

        // 认证方式：0=Password 1=PublicKey
        let authRaw = dict["connection\\authentication.method"]
            ?? dict["authentication.method"]
            ?? dict["authmethod"]
            ?? "0"
        let authMethod: AuthMethod = (authRaw == "1" || authRaw.lowercased() == "publickey")
            ? .privateKey : .password

        let session = Session(
            name: sessionName.trimmingCharacters(in: .whitespaces),
            host: host,
            port: port,
            username: username,
            authMethod: authMethod
        )
        return [session]
    }

    // MARK: - SecureCRT .ini 解析器

    /// SecureCRT 导出的 .ini 格式
    ///
    /// ```
    /// [/SSH2]
    /// S:"Hostname"=myhost.example.com
    /// D:"Port Number"=00000016
    /// S:"Username"=admin
    ///
    /// [/SSH2/Auth]
    /// S:"Auth0"=Password
    /// ```
    static func parseSecureCRT(data: Data) throws -> [Session] {
        guard !data.isEmpty else { throw ParseError.emptyFile }
        guard let text = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1)
        else { throw ParseError.invalidEncoding }

        // SecureCRT .ini 有 S:"Key"=Value 和 D:"Key"=hexvalue 两种值类型
        var props: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            // 匹配 S:"Key"=Value 或 D:"Key"=hexvalue
            if let range = t.range(of: #"^[SDZ]:"([^"]+)"=(.*)$"#, options: .regularExpression) {
                let _ = range // avoid warning
                let parts = t.dropFirst(2) // remove 'S:' or 'D:'
                if let eqIdx = parts.firstIndex(of: "=") {
                    let rawKey = String(parts[parts.startIndex..<eqIdx])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        .lowercased()
                    var val = String(parts[parts.index(after: eqIdx)...])

                    // D: 类型是十六进制整数
                    if t.hasPrefix("D:") {
                        val = String(Int(val, radix: 16) ?? 0)
                    }
                    props[rawKey] = val
                }
            }
        }

        // 也支持普通 INI 格式的 SecureCRT 文件
        let dict = parseINI(text)
        props.merge(dict) { existing, _ in existing }

        let host = props["hostname"] ?? props["host"] ?? ""
        guard !host.isEmpty else { throw ParseError.noSessionsFound }

        let portVal = props["port number"] ?? props["port"] ?? "22"
        let port = Int32(portVal) ?? 22
        let username = props["username"] ?? props["login name"] ?? ""
        let sessionName = "\(username.isEmpty ? "" : username + "@")\(host)"

        let authStr = (props["auth0"] ?? props["auth"] ?? "").lowercased()
        let authMethod: AuthMethod = authStr.contains("publickey") || authStr.contains("key")
            ? .privateKey : .password

        let session = Session(
            name: sessionName,
            host: host,
            port: port,
            username: username,
            authMethod: authMethod
        )
        return [session]
    }

    // MARK: - PuTTY .reg 解析器

    /// PuTTY Windows 注册表导出文件（.reg）
    /// 支持同时导入多个会话（每个 [HKEY_...Sessions\SessionName] 为一个会话）
    ///
    /// ```
    /// Windows Registry Editor Version 5.00
    ///
    /// [HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\My%20Server]
    /// "HostName"="192.168.1.1"
    /// "PortNumber"=dword:00000016
    /// "UserName"="admin"
    /// "Protocol"="ssh"
    /// ```
    static func parsePuTTY(data: Data) throws -> [Session] {
        guard !data.isEmpty else { throw ParseError.emptyFile }
        // PuTTY .reg 可能是 UTF-16 LE（Windows 默认）
        let text: String
        if data.count >= 2 && data[0] == 0xFF && data[1] == 0xFE {
            text = String(data: data, encoding: .utf16LittleEndian) ?? ""
        } else {
            text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1252)
                ?? ""
        }
        guard !text.isEmpty else { throw ParseError.invalidEncoding }

        var sessions: [Session] = []
        var currentSessionName: String? = nil
        var currentProps: [String: String] = [:]

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)

            // 匹配 PuTTY Sessions 节：[HKEY_CURRENT_USER\...\Sessions\SessionName]
            if t.hasPrefix("[") && t.hasSuffix("]") {
                // 保存上一个会话
                if let name = currentSessionName {
                    if let session = buildPuTTYSession(name: name, props: currentProps) {
                        sessions.append(session)
                    }
                }
                // 检查是否是 Sessions 节
                let key = String(t.dropFirst().dropLast())
                let sessionsMarker = "\\Sessions\\"
                if let range = key.range(of: sessionsMarker) {
                    let rawName = String(key[range.upperBound...])
                    // URL decode（PuTTY 用 % 编码空格等字符）
                    currentSessionName = rawName
                        .replacingOccurrences(of: "%20", with: " ")
                        .replacingOccurrences(of: "%2F", with: "/")
                        .replacingOccurrences(of: "%25", with: "%")
                    currentProps = [:]
                } else {
                    currentSessionName = nil
                    currentProps = [:]
                }
                continue
            }

            guard currentSessionName != nil else { continue }

            // 匹配 "Key"="StringValue" 或 "Key"=dword:hexvalue
            if t.hasPrefix("\""), let eqIdx = findRegEq(in: t) {
                let keyPart = String(t[t.index(after: t.startIndex)..<eqIdx])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    .lowercased()
                let valPart = String(t[t.index(after: eqIdx)...])

                var value: String
                if valPart.hasPrefix("\"") {
                    // 字符串值
                    value = valPart.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                } else if valPart.lowercased().hasPrefix("dword:") {
                    // 十六进制整数
                    let hex = String(valPart.dropFirst(6))
                    value = String(Int(hex, radix: 16) ?? 0)
                } else {
                    value = valPart
                }
                currentProps[keyPart] = value
            }
        }

        // 处理最后一个会话
        if let name = currentSessionName {
            if let session = buildPuTTYSession(name: name, props: currentProps) {
                sessions.append(session)
            }
        }

        guard !sessions.isEmpty else { throw ParseError.noSessionsFound }
        return sessions
    }

    // MARK: - PuTTY 会话构建

    private static func buildPuTTYSession(name: String, props: [String: String]) -> Session? {
        // 跳过 Default Settings（PuTTY 默认模板，非真实会话）
        guard name != "Default%20Settings" && name != "Default Settings" else { return nil }

        let host = props["hostname"] ?? ""
        guard !host.isEmpty else { return nil }

        let portStr = props["portnumber"] ?? "22"
        let port = Int32(portStr) ?? 22
        let username = props["username"] ?? ""

        // PuTTY 协议判断（默认 SSH）
        let protocol_ = (props["protocol"] ?? "ssh").lowercased()
        guard protocol_.contains("ssh") else { return nil } // 只导入 SSH 会话

        let sessionName = name.isEmpty ? host : name

        return Session(
            name: sessionName,
            host: host,
            port: port,
            username: username,
            authMethod: .password
        )
    }

    // MARK: - 通用 INI 解析

    /// 解析 INI 格式，返回 "section.key"→value 的扁平化字典（全小写）
    private static func parseINI(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        var currentSection = ""

        for line in text.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty && !t.hasPrefix(";") && !t.hasPrefix("#") else { continue }

            if t.hasPrefix("[") && t.hasSuffix("]") {
                currentSection = String(t.dropFirst().dropLast()).lowercased()
            } else if let eqIdx = t.firstIndex(of: "=") {
                let key = String(t[t.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                let val = String(t[t.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                let fullKey = currentSection.isEmpty ? key : "\(currentSection).\(key)"
                result[fullKey] = val
                // 也存无前缀版（方便跨 section 查找）
                result[key] = val
            }
        }
        return result
    }

    // MARK: - 注册表等号查找（跳过字符串内的 =）

    private static func findRegEq(in str: String) -> String.Index? {
        var inQuote = false
        var i = str.startIndex
        while i < str.endIndex {
            let c = str[i]
            if c == "\"" { inQuote.toggle() }
            else if c == "=" && !inQuote { return i }
            i = str.index(after: i)
        }
        return nil
    }
}
