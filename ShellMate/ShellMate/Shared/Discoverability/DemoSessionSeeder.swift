import Foundation

// Phase 3：首次启动注入演示会话（解 UE-P1#7 示例会话）
// 检测 hasInjectedDemoSession AppStorage flag + sessions.isEmpty 双条件
// 注入 localhost:22 演示会话，让新用户首屏不空

@MainActor
enum DemoSessionSeeder {

    private static let injectedKey = "shellmate.demoSession.injected"

    /// 在 App 启动期调用；若首次启动且无会话，注入一个 localhost 演示会话
    static func injectIfNeeded(sessionStore: SessionStore) async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: injectedKey) else { return }
        // 已有会话则不注入（用户已经在使用）
        guard sessionStore.sessions.isEmpty else {
            defaults.set(true, forKey: injectedKey)
            return
        }

        let demo = Session(
            name: "示例：本机 SSH",
            host: "localhost",
            port: 22,
            username: NSUserName(),
            connectionType: .ssh
        )
        await sessionStore.saveSession(demo)
        defaults.set(true, forKey: injectedKey)
    }
}
