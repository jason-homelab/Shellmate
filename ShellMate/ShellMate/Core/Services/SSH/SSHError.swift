import Foundation

/// SSH 错误类型
/// 定义 SSH 连接过程中可能发生的所有错误
enum SSHError: LocalizedError {

    // MARK: - 连接错误

    /// 无法解析主机名
    case dnsResolutionFailed(host: String)

    /// TCP 连接失败
    case connectionFailed(host: String, port: Int32, underlying: Error?)

    /// 连接超时
    case connectionTimeout(host: String, port: Int32)

    /// 连接被拒绝
    case connectionRefused(host: String, port: Int32)

    /// 网络不可达
    case networkUnreachable

    // MARK: - SSH 协议错误

    /// SSH 握手失败
    case handshakeFailed(reason: String)

    /// 不支持的 SSH 协议版本
    case unsupportedProtocolVersion(version: String)

    /// 密钥交换失败
    case keyExchangeFailed(reason: String)

    /// 算法协商失败
    case algorithmNegotiationFailed(type: String)

    // MARK: - 认证错误

    /// 认证失败
    case authenticationFailed(method: String, reason: String)

    /// 密码错误
    case invalidPassword

    /// 私钥无效
    case invalidPrivateKey(reason: String)

    /// 私钥密码错误
    case invalidPassphrase

    /// 认证方式不支持
    case authMethodNotSupported(method: String)

    /// SSH Agent 不可用
    case agentNotAvailable

    /// SSH Agent 认证失败
    case agentAuthFailed(reason: String)

    // MARK: - 主机密钥错误

    /// 主机密钥验证失败
    case hostKeyVerificationFailed(fingerprint: String)

    /// 主机密钥已变更（可能的中间人攻击）
    case hostKeyChanged(oldFingerprint: String, newFingerprint: HostKeyFingerprint)

    /// 首次连接到未知主机，需要用户确认
    case hostKeyUnknown(HostKeyFingerprint)

    /// 主机密钥类型不支持
    case unsupportedHostKeyType(type: String)

    // MARK: - 会话错误

    /// 会话未初始化
    case sessionNotInitialized

    /// 会话已关闭
    case sessionClosed

    /// 通道打开失败
    case channelOpenFailed(reason: String)

    /// PTY 请求失败
    case ptyRequestFailed(reason: String)

    /// Shell 启动失败
    case shellStartFailed(reason: String)

    /// 通道未打开
    case channelNotOpen

    /// 读取超时
    case readTimeout

    /// 写入失败
    case writeFailed(reason: String)

    // MARK: - SFTP 错误

    /// SFTP 子系统未连接
    case sftpNotConnected

    /// SFTP 打开文件/目录失败
    case sftpOpenFailed(path: String, code: UInt32)

    /// SFTP 读取失败
    case sftpReadFailed(code: UInt32)

    /// SFTP 写入失败
    case sftpWriteFailed(code: UInt32)

    /// SFTP 权限拒绝
    case sftpPermissionDenied(path: String)

    /// SFTP 文件/目录不存在
    case sftpFileNotFound(path: String)

    /// SFTP 传输失败
    case sftpTransferFailed(reason: String)

    /// SFTP 操作失败
    case sftpOperationFailed(operation: String, code: UInt32)

    // MARK: - 端口转发错误

    /// 隧道端口绑定失败
    case tunnelBindFailed(port: Int, reason: String)

    /// 隧道远端监听失败
    case tunnelListenFailed(port: Int, reason: String)

    /// 隧道对应的 SSH 会话未连接
    case tunnelSessionNotConnected

    // MARK: - 通用错误

    /// libssh2 内部错误
    case libssh2Error(code: Int32, message: String)

    /// 未知错误
    case unknown(underlying: Error?)

    /// 操作被取消
    case cancelled

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .dnsResolutionFailed(let host):
            return "无法解析主机名: \(host)"

        case .connectionFailed(let host, let port, _):
            return "无法连接到 \(host):\(port)"

        case .connectionTimeout(let host, let port):
            return "连接超时: \(host):\(port)"

        case .connectionRefused(let host, let port):
            return "连接被拒绝: \(host):\(port)"

        case .networkUnreachable:
            return "网络不可达，请检查网络连接"

        case .handshakeFailed(let reason):
            return "SSH 握手失败: \(reason)"

        case .unsupportedProtocolVersion(let version):
            return "不支持的 SSH 协议版本: \(version)"

        case .keyExchangeFailed(let reason):
            return "密钥交换失败: \(reason)"

        case .algorithmNegotiationFailed(let type):
            return "算法协商失败: \(type)"

        case .authenticationFailed(let method, let reason):
            return "认证失败 (\(method)): \(reason)"

        case .invalidPassword:
            return "密码错误"

        case .invalidPrivateKey(let reason):
            return "私钥无效: \(reason)"

        case .invalidPassphrase:
            return "私钥密码错误"

        case .authMethodNotSupported(let method):
            return "认证方式不支持: \(method)"

        case .agentNotAvailable:
            return "SSH Agent 不可用"

        case .agentAuthFailed(let reason):
            return "SSH Agent 认证失败: \(reason)"

        case .hostKeyVerificationFailed(let fingerprint):
            return "主机密钥验证失败: \(fingerprint)"

        case .hostKeyChanged(_, let newFingerprint):
            return "警告：主机密钥已变更！新指纹: \(newFingerprint.sha256Display)"

        case .hostKeyUnknown(let fingerprint):
            return "首次连接到此主机，密钥指纹: \(fingerprint.sha256Display)"

        case .unsupportedHostKeyType(let type):
            return "不支持的主机密钥类型: \(type)"

        case .sessionNotInitialized:
            return "SSH 会话未初始化"

        case .sessionClosed:
            return "SSH 会话已关闭"

        case .channelOpenFailed(let reason):
            return "无法打开通道: \(reason)"

        case .ptyRequestFailed(let reason):
            return "PTY 请求失败: \(reason)"

        case .shellStartFailed(let reason):
            return "Shell 启动失败: \(reason)"

        case .channelNotOpen:
            return "通道未打开"

        case .readTimeout:
            return "读取超时"

        case .writeFailed(let reason):
            return "写入失败: \(reason)"

        case .sftpNotConnected:
            return "SFTP 未连接"

        case .sftpOpenFailed(let path, let code):
            return "SFTP 无法打开: \(path)（错误码: \(code)）"

        case .sftpReadFailed(let code):
            return "SFTP 读取失败（错误码: \(code)）"

        case .sftpWriteFailed(let code):
            return "SFTP 写入失败（错误码: \(code)）"

        case .sftpPermissionDenied(let path):
            return "SFTP 权限拒绝: \(path)"

        case .sftpFileNotFound(let path):
            return "SFTP 文件不存在: \(path)"

        case .sftpTransferFailed(let reason):
            return "SFTP 传输失败: \(reason)"

        case .sftpOperationFailed(let operation, let code):
            return "SFTP 操作失败（\(operation)，错误码: \(code)）"

        case .tunnelBindFailed(let port, let reason):
            return "端口 \(port) 绑定失败: \(reason)"

        case .tunnelListenFailed(let port, let reason):
            return "远端端口 \(port) 监听失败: \(reason)"

        case .tunnelSessionNotConnected:
            return "隧道所绑定的 SSH 会话未连接"

        case .libssh2Error(let code, let message):
            return "libssh2 错误 (\(code)): \(message)"

        case .unknown(let underlying):
            if let error = underlying {
                return "未知错误: \(error.localizedDescription)"
            }
            return "未知错误"

        case .cancelled:
            return "操作已取消"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .dnsResolutionFailed:
            return "请检查主机名是否正确，或尝试使用 IP 地址"

        case .connectionFailed, .connectionRefused:
            return "请检查主机地址和端口是否正确，以及服务器 SSH 服务是否运行"

        case .connectionTimeout:
            return "请检查网络连接，或增加连接超时时间"

        case .networkUnreachable:
            return "请检查网络连接"

        case .invalidPassword:
            return "请检查密码是否正确"

        case .invalidPrivateKey:
            return "请检查私钥文件是否有效"

        case .invalidPassphrase:
            return "请检查私钥密码是否正确"

        case .hostKeyChanged:
            return "如果您确认服务器是安全的，请删除旧的主机密钥记录后重试"

        default:
            return nil
        }
    }

    /// 是否为可恢复的错误（可以重试）
    var isRecoverable: Bool {
        switch self {
        case .connectionTimeout, .networkUnreachable:
            return true
        default:
            return false
        }
    }

    /// 是否为安全相关的错误
    var isSecurityRelated: Bool {
        switch self {
        case .hostKeyVerificationFailed, .hostKeyChanged, .hostKeyUnknown,
             .invalidPassword, .invalidPrivateKey, .invalidPassphrase,
             .authenticationFailed:
            return true
        default:
            return false
        }
    }
}
