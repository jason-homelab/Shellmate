import SwiftUI

/// ShellMate 主应用入口
/// macOS SSH 会话管理工具
@main
struct ShellMateApp: App {

    // MARK: - 属性

    /// 应用程序代理
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Core Data 持久化控制器
    let persistenceController = PersistenceController.shared

    // MARK: - 应用场景

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    configureAppearance()
                }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            AppCommands()
        }
    }

    // MARK: - 外观配置

    private func configureAppearance() {
        // W15.1 冷启动优化：在 UI 就绪后立即在后台预热 HighlightEngine
        Task { @MainActor in
            _ = HighlightEngine.shared
            // W3 横切层：能力注册（启动期完成，保证 ⌘K / 工具栏 / Onboarding 三处共享）
            CapabilityBootstrap.registerInitialCapabilities()
            // W4 横切层：通知权限按需申请（不打扰，仅在首次需要时弹窗）
            await SystemNotificationBridge.shared.refreshAuthorizationStatus()
            // Phase 13：检查 AI 引导提示（7 天后 + 一次性）
            OnboardingDirector.checkAITip()
        }
        // 注：NSApp.appearance 由 AppDelegate.windowModeObserver (KVO) 统一管理
    }
}

