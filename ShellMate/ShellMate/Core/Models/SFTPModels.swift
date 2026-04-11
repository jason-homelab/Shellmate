import Foundation

// MARK: - SFTP 文件类型

/// SFTP 文件类型
enum SFTPFileType: Equatable {
    case directory
    case regularFile
    case symlink
    case other

    /// SF Symbols 图标名
    var sfSymbolName: String {
        switch self {
        case .directory:    return "folder.fill"
        case .regularFile:  return "doc.fill"
        case .symlink:      return "arrow.triangle.branch"
        case .other:        return "questionmark.square"
        }
    }

    /// 是否为可进入的目录类型
    var isDirectory: Bool {
        return self == .directory
    }
}

// MARK: - SFTP 文件条目

/// 远程文件/目录条目
struct SFTPFileItem: Identifiable, Equatable {

    let id: UUID
    /// 文件名（不含路径）
    let name: String
    /// 完整远程路径
    let path: String
    /// 文件类型
    let fileType: SFTPFileType
    /// 文件大小（字节）
    let size: UInt64
    /// Unix 权限位
    let permissions: UInt32
    /// 修改时间
    let modifiedAt: Date?
    /// 所属用户 ID
    let uid: UInt32
    /// 所属组 ID
    let gid: UInt32

    init(
        name: String,
        path: String,
        fileType: SFTPFileType,
        size: UInt64 = 0,
        permissions: UInt32 = 0,
        modifiedAt: Date? = nil,
        uid: UInt32 = 0,
        gid: UInt32 = 0
    ) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.fileType = fileType
        self.size = size
        self.permissions = permissions
        self.modifiedAt = modifiedAt
        self.uid = uid
        self.gid = gid
    }

    /// 格式化权限字符串（如 -rwxr-xr-x）
    var permissionsString: String {
        let typeChar: Character
        switch fileType {
        case .directory:    typeChar = "d"
        case .symlink:      typeChar = "l"
        case .regularFile:  typeChar = "-"
        case .other:        typeChar = "?"
        }

        func bit(_ p: UInt32, _ pos: Int) -> Character {
            let rwx: [Character] = ["r", "w", "x"]
            return (permissions >> UInt32(pos)) & 1 == 1 ? rwx[pos % 3] : "-"
        }

        let u = "\(bit(permissions, 8))\(bit(permissions, 7))\(bit(permissions, 6))"
        let g = "\(bit(permissions, 5))\(bit(permissions, 4))\(bit(permissions, 3))"
        let o = "\(bit(permissions, 2))\(bit(permissions, 1))\(bit(permissions, 0))"
        return "\(typeChar)\(u)\(g)\(o)"
    }

    /// 格式化文件大小
    var formattedSize: String {
        guard fileType == .regularFile else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    /// 格式化修改时间
    var formattedDate: String {
        guard let date = modifiedAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - 本地文件条目

/// 本地文件/目录条目（用于 SFTP 双栏面板本地侧浏览）
struct LocalFileItem: Identifiable {

    let id: UUID
    /// 文件名（不含路径）
    let name: String
    /// 完整本地路径
    let path: String
    /// 是否为目录
    let isDirectory: Bool
    /// 文件大小（字节，目录为 0）
    let size: UInt64
    /// 修改时间
    let modifiedAt: Date?

    init(name: String, path: String, isDirectory: Bool, size: UInt64 = 0, modifiedAt: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedAt = modifiedAt
    }

    /// 格式化文件大小（目录显示 —）
    var formattedSize: String {
        guard !isDirectory else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    /// 格式化修改时间
    var formattedDate: String {
        guard let date = modifiedAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy h:mm a"
        return formatter.string(from: date)
    }

    /// SF Symbols 图标名
    var sfSymbolName: String {
        isDirectory ? "folder.fill" : "doc.fill"
    }
}

// MARK: - 传输方向

/// 文件传输方向
enum SFTPTransferDirection {
    case upload   // 本地 → 远程
    case download // 远程 → 本地

    var displayName: String {
        switch self {
        case .upload:   return "上传"
        case .download: return "下载"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .upload:   return "arrow.up.circle.fill"
        case .download: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - 传输状态

/// 文件传输状态
enum SFTPTransferState: Equatable {
    case pending
    case inProgress
    case completed
    case failed(String)
    case cancelled

    var displayName: String {
        switch self {
        case .pending:          return "等待中"
        case .inProgress:       return "传输中"
        case .completed:        return "已完成"
        case .failed(let msg):  return "失败: \(msg)"
        case .cancelled:        return "已取消"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        default: return false
        }
    }
}

// MARK: - 传输条目

/// 单个文件传输任务
final class SFTPTransferItem: Identifiable, ObservableObject, @unchecked Sendable {

    let id: UUID
    /// 本地文件路径（上传时为源路径，下载时为目标路径）
    let localPath: String
    /// 远程文件路径（下载时为源路径，上传时为目标路径）
    let remotePath: String
    /// 文件名（用于显示）
    let fileName: String
    /// 传输方向
    let direction: SFTPTransferDirection
    /// 文件总大小（字节）
    @Published var totalBytes: UInt64
    /// 已传输字节数
    @Published var transferredBytes: UInt64 = 0
    /// 传输状态
    @Published var state: SFTPTransferState = .pending
    /// 当前传输速度（字节/秒）
    @Published var bytesPerSecond: Double = 0

    /// 传输进度 0.0–1.0
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }

    /// 剩余时间（秒），仅在传输中时有意义
    var estimatedSecondsRemaining: Double? {
        guard state == .inProgress, bytesPerSecond > 0, totalBytes > transferredBytes else {
            return nil
        }
        return Double(totalBytes - transferredBytes) / bytesPerSecond
    }

    /// 取消标志（用于中断传输循环）
    var isCancelled: Bool = false

    init(
        localPath: String,
        remotePath: String,
        direction: SFTPTransferDirection,
        totalBytes: UInt64 = 0
    ) {
        self.id = UUID()
        self.localPath = localPath
        self.remotePath = remotePath
        self.fileName = (direction == .upload ? localPath : remotePath)
            .components(separatedBy: "/").last ?? "未知文件"
        self.direction = direction
        self.totalBytes = totalBytes
    }
}
