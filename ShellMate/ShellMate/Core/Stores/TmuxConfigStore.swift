import Foundation

/// tmux 配置持久化存储
/// 使用 UserDefaults 以 "tmux.config.<sessionId>" 为键存储每个会话的 TmuxConfig JSON
/// （独立于 Core Data，避免模型迁移）
final class TmuxConfigStore {

    private static let keyPrefix = "tmux.config."
    private static let encoder   = JSONEncoder()
    private static let decoder   = JSONDecoder()

    /// 读取指定 Session 的 tmux 配置（未存储则返回默认值）
    static func load(sessionId: UUID) -> TmuxConfig {
        let key = keyPrefix + sessionId.uuidString
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? decoder.decode(TmuxConfig.self, from: data) else {
            return TmuxConfig()
        }
        return config
    }

    /// 保存指定 Session 的 tmux 配置
    static func save(_ config: TmuxConfig, sessionId: UUID) {
        let key = keyPrefix + sessionId.uuidString
        guard let data = try? encoder.encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// 删除指定 Session 的 tmux 配置（会话被删除时调用）
    static func remove(sessionId: UUID) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + sessionId.uuidString)
    }
}
