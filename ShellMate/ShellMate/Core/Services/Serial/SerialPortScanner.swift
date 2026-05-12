import Foundation

/// 串口扫描器
/// 枚举 macOS 上可用的串口设备（USB 串口、蓝牙串口、内置串口）
enum SerialPortScanner {

    /// 扫描并返回当前可用的串口路径列表
    /// 覆盖 /dev/cu.* 下的所有设备（cu.* 在 macOS 上是调用方设备节点，适合主动拨出）
    static func availablePorts() -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: "/dev") else { return [] }

        return entries
            .filter { name in
                // cu.* 前缀：适合主动连接（tty.* 是应答设备节点，用于被动监听）
                // 常见：cu.usbserial-*, cu.usbmodem*, cu.Bluetooth-*, cu.SLAB_*
                name.hasPrefix("cu.")
            }
            .map { "/dev/\($0)" }
            .sorted()
    }

    /// 常用串口（当无 USB 设备接入时的提示列表）
    static let commonPorts = [
        "/dev/cu.usbserial-1",
        "/dev/cu.usbmodem1",
        "/dev/cu.Bluetooth-Serial-1",
    ]
}
