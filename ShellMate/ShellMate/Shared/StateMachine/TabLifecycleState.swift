import Foundation

// W2 新增：Tab 生命周期状态机（解 UE-P0#3 Tab 误关保护）

enum TabLifecycleState: UIState {

    case active(activity: ActivityLevel)
    case background(activity: BackgroundActivity)
    case closing
    case closed(recoverable: Bool)

    static var initial: TabLifecycleState { .active(activity: .idle) }

    enum ActivityLevel: Equatable, Sendable {
        case idle
        case runningCommand    // 最近 5s 有输出
        case error
    }

    enum BackgroundActivity: Equatable, Sendable {
        case idle
        case unreadOutput(count: Int)
    }

    enum Event: Sendable {
        case activated
        case deactivated
        case outputReceived
        case errorOccurred
        case idleTimerFired
        case closeRequested
        case closeConfirmed
        case reopened
    }

    mutating func reduce(_ event: Event) {
        switch (self, event) {
        case (.background, .activated):
            self = .active(activity: .idle)

        case (.active, .deactivated):
            self = .background(activity: .idle)

        case (.active, .outputReceived):
            self = .active(activity: .runningCommand)

        case (.background(let bg), .outputReceived):
            if case .unreadOutput(let n) = bg {
                self = .background(activity: .unreadOutput(count: n + 1))
            } else {
                self = .background(activity: .unreadOutput(count: 1))
            }

        case (.active, .errorOccurred):
            self = .active(activity: .error)

        case (.active(.runningCommand), .idleTimerFired):
            self = .active(activity: .idle)

        case (_, .closeRequested):
            // 状态机不直接关闭，由 UI 决定是否弹 confirm
            break

        case (_, .closeConfirmed):
            self = .closing

        case (.closing, _):
            self = .closed(recoverable: true)

        case (.closed, .reopened):
            self = .active(activity: .idle)

        default:
            break
        }
    }
}

// MARK: - UI 派生

extension TabLifecycleState {

    /// 关闭时是否需要 confirm（活动会话/未读输出/出错时需要）
    var requiresCloseConfirmation: Bool {
        switch self {
        case .active(.runningCommand), .active(.error):
            return true
        default:
            return false
        }
    }

    /// 是否显示活动指示点
    var showsActivityDot: Bool {
        switch self {
        case .active(.runningCommand), .active(.error):
            return true
        default:
            return false
        }
    }

    /// 未读输出 badge 数字（0 表示不显示）
    var unreadBadge: Int {
        if case .background(.unreadOutput(let n)) = self { return n }
        return 0
    }
}
