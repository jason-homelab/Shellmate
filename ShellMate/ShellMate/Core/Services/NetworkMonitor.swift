import Network
import Combine

// MARK: - 21.4 网络状态监控（NWPathMonitor）

/// 监听系统网络可达性，供 AI 服务在请求前做离线预检。
/// 使用 `NWPathMonitor` 实时监听路径变更，避免无效 API 请求。
@MainActor
final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .wifi

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.shellmate.networkmonitor", qos: .utility)

    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case other
        case none

        var description: String {
            switch self {
            case .wifi:           return "Wi-Fi"
            case .cellular:       return "蜂窝网络"
            case .wiredEthernet:  return "有线以太网"
            case .other:          return "其他网络"
            case .none:           return "无网络连接"
            }
        }
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isConnected = path.status == .satisfied
                self.connectionType = self.detectType(from: path)
            }
        }
        monitor.start(queue: queue)
    }

    private func detectType(from path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else { return .none }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        return .other
    }

    deinit { monitor.cancel() }
}
