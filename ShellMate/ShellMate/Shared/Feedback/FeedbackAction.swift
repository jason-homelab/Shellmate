import SwiftUI
import Foundation

// W1 新增：Feedback 中可执行的恢复动作
// 让错误诊断卡片本身就是操作入口，根除 UE Review P1#8 "错误恢复路径过长"

@MainActor
struct FeedbackAction: Identifiable {

    let id = UUID()
    let title: LocalizedStringKey
    let style: Style
    let handler: () async -> Void

    enum Style {
        case primary
        case secondary
        case destructive
        case dismiss
    }

    init(
        title: LocalizedStringKey,
        style: Style = .secondary,
        handler: @escaping () async -> Void
    ) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

// 预设动作工厂方法（业务侧只需描述意图，handler 由 W5 接入）
extension FeedbackAction {

    static func retry(handler: @escaping () async -> Void) -> FeedbackAction {
        FeedbackAction(title: "feedback.action.retry", style: .primary, handler: handler)
    }

    static func editCredentials(handler: @escaping () async -> Void) -> FeedbackAction {
        FeedbackAction(title: "feedback.action.edit_credentials", style: .primary, handler: handler)
    }

    static func acceptHostKey(handler: @escaping () async -> Void) -> FeedbackAction {
        FeedbackAction(title: "feedback.action.accept_host_key", style: .destructive, handler: handler)
    }

    static func testNetwork(handler: @escaping () async -> Void) -> FeedbackAction {
        FeedbackAction(title: "feedback.action.test_network", style: .secondary, handler: handler)
    }

    static func openSettings(handler: @escaping () async -> Void) -> FeedbackAction {
        FeedbackAction(title: "feedback.action.open_settings", style: .secondary, handler: handler)
    }

    static let dismiss = FeedbackAction(
        title: "feedback.action.dismiss",
        style: .dismiss,
        handler: { /* no-op，由 Center 处理 */ }
    )
}
