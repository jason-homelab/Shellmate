import SwiftUI
import Foundation

// W1 新增：Feedback 事件描述
// 业务侧通过构造 FeedbackEvent 发起反馈，FeedbackCenter 路由到对应通道

@MainActor
struct FeedbackEvent: Identifiable {

    let id = UUID()
    let level: DesignTokens.Semantic.FeedbackLevel
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let actions: [FeedbackAction]
    let channel: Channel
    let lifetime: Lifetime
    let createdAt: Date = Date()

    enum Channel {
        case toast
        case banner(BannerSlot)
        case systemNotification
    }

    enum BannerSlot {
        case terminal     // 嵌入终端中央 overlay
        case sessionForm  // 表单底部
        case global       // 主窗口顶部
    }

    enum Lifetime {
        case auto(TimeInterval)
        case untilDismissed
        case untilEventResolved
    }

    init(
        level: DesignTokens.Semantic.FeedbackLevel,
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        actions: [FeedbackAction] = [],
        channel: Channel = .toast,
        lifetime: Lifetime = .auto(3.0)
    ) {
        self.level = level
        self.title = title
        self.message = message
        self.actions = actions
        self.channel = channel
        self.lifetime = lifetime
    }
}

// 便捷构造器
extension FeedbackEvent {

    static func info(_ title: LocalizedStringKey, message: LocalizedStringKey? = nil) -> FeedbackEvent {
        FeedbackEvent(level: .info, title: title, message: message)
    }

    static func success(_ title: LocalizedStringKey, message: LocalizedStringKey? = nil) -> FeedbackEvent {
        FeedbackEvent(level: .success, title: title, message: message)
    }

    static func warn(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        actions: [FeedbackAction] = []
    ) -> FeedbackEvent {
        FeedbackEvent(
            level: .warn,
            title: title,
            message: message,
            actions: actions,
            channel: actions.isEmpty ? .toast : .banner(.global),
            lifetime: actions.isEmpty ? .auto(4.0) : .untilDismissed
        )
    }

    static func error(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        actions: [FeedbackAction] = [],
        bannerSlot: BannerSlot = .global
    ) -> FeedbackEvent {
        FeedbackEvent(
            level: .error,
            title: title,
            message: message,
            actions: actions,
            channel: .banner(bannerSlot),
            lifetime: .untilDismissed
        )
    }
}
