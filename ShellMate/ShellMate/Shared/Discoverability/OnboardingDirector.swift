import SwiftUI
import Foundation

// Phase 13：首次连接成功后的引导（解 UE-P1#6 OnboardingDirector）
// 简化版：监听首次会话连接成功 → 触发"试试 ⌘K 命令面板"Toast
// 单次显示，永久持久化标记

@MainActor
enum OnboardingDirector {

    private static let didShowFirstConnectionTipKey = "shellmate.onboarding.firstConnectionTipShown"
    private static let didShowAITipKey = "shellmate.onboarding.aiTipShown"

    /// 首次连接成功时调用。已显示过则 no-op。
    static func onFirstSuccessfulConnection() {
        guard !UserDefaults.standard.bool(forKey: didShowFirstConnectionTipKey) else { return }
        UserDefaults.standard.set(true, forKey: didShowFirstConnectionTipKey)

        // 延迟 1.5s 让用户先看到终端已连接的兴奋感再弹引导
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            FeedbackCenter.shared.present(.info(
                "试试 ⌘K 命令面板",
                message: "在 ShellMate 中搜索所有功能：AI 助手、SFTP、Tmux、端口转发…"
            ))
        }
    }

    /// 7 天后仍未使用 AI 时触发提示（一次性）
    static func checkAITip() {
        guard !UserDefaults.standard.bool(forKey: didShowAITipKey) else { return }
        // 此处简化为：每次启动随机检查（生产应基于使用频率）
        let firstLaunchDate = UserDefaults.standard.object(forKey: "shellmate.firstLaunchDate") as? Date
        if firstLaunchDate == nil {
            UserDefaults.standard.set(Date(), forKey: "shellmate.firstLaunchDate")
            return
        }
        guard let firstDate = firstLaunchDate,
              Date().timeIntervalSince(firstDate) > 7 * 24 * 3600 else { return }
        UserDefaults.standard.set(true, forKey: didShowAITipKey)

        FeedbackCenter.shared.present(.info(
            "✦ AI 助手可帮你写命令",
            message: "在终端中按 ⌘I 唤起 AI，描述你想做什么，让 AI 给出命令"
        ))
    }

    /// 调试用 / 测试用：重置所有引导标记
    static func resetAllTips() {
        UserDefaults.standard.removeObject(forKey: didShowFirstConnectionTipKey)
        UserDefaults.standard.removeObject(forKey: didShowAITipKey)
    }
}
