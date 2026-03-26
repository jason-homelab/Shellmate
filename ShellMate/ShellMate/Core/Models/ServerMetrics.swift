import Foundation

/// 服务器实时性能指标
struct ServerMetrics: Equatable {
    /// CPU 使用率（0~100）
    var cpuUsage: Double
    /// 已用内存（字节）
    var memoryUsed: Int64
    /// 总内存（字节）
    var memoryTotal: Int64
    /// 磁盘已用空间（字节）
    var diskUsed: Int64
    /// 磁盘总空间（字节）
    var diskTotal: Int64
    /// 网络下载速率（字节/秒）
    var networkRxRate: Double
    /// 网络上传速率（字节/秒）
    var networkTxRate: Double
    /// 数据采集时间
    var updatedAt: Date

    // MARK: - 格式化辅助

    /// 格式化字节数（自动选 GB/MB/KB）
    static func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        let mb = Double(bytes) / 1_048_576.0
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024.0)
    }

    /// 格式化网络速率（自动选 MB/s 或 KB/s）
    static func formatRate(_ bytesPerSec: Double) -> String {
        let mbps = bytesPerSec / 1_048_576.0
        let kbps = bytesPerSec / 1024.0
        if mbps >= 1 { return String(format: "%.1f MB/s", mbps) }
        if kbps >= 0.1 { return String(format: "%.0f KB/s", kbps) }
        return "0 B/s"
    }

    /// CPU 颜色：低(绿) / 中(黄) / 高(红)
    var cpuColor: CPULoad {
        if cpuUsage < 60 { return .low }
        if cpuUsage < 85 { return .medium }
        return .high
    }

    enum CPULoad {
        case low, medium, high
    }

    /// 内存使用率（0~1）
    var memoryRatio: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal)
    }
}
