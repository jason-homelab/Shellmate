import Foundation

// W2 新增：轻量级 UI 状态机集合
// AIConsent / SettingsDirty / OnboardingFlow

// MARK: - AIConsentState

enum AIConsentState: UIState {

    case notRequested
    case viewingPolicy   // 用户打开 AI 面板，但未同意（解 UE-P1#12 Inline 引导）
    case granted(at: Date)
    case denied

    static var initial: AIConsentState { .notRequested }

    enum Event: Sendable {
        case openedPanel
        case agreed
        case declined
        case revoked
    }

    mutating func reduce(_ event: Event) {
        switch (self, event) {
        case (.notRequested, .openedPanel),
             (.denied, .openedPanel):
            self = .viewingPolicy
        case (.viewingPolicy, .agreed):
            self = .granted(at: Date())
        case (.viewingPolicy, .declined):
            self = .denied
        case (.granted, .revoked):
            self = .notRequested
        default:
            break
        }
    }

    var canUseAI: Bool {
        if case .granted = self { return true }
        return false
    }

    var showsInlinePolicy: Bool {
        self == .viewingPolicy || self == .notRequested
    }
}

// MARK: - SettingsDirtyState（解 UE-P1#14 未保存提醒）

enum SettingsDirtyState: UIState {

    case clean
    case dirty(changedKeys: Set<String>)

    static var initial: SettingsDirtyState { .clean }

    enum Event: Sendable {
        case changed(key: String)
        case saved
        case discarded
    }

    mutating func reduce(_ event: Event) {
        switch (self, event) {
        case (.clean, .changed(let key)):
            self = .dirty(changedKeys: [key])
        case (.dirty(var keys), .changed(let key)):
            keys.insert(key)
            self = .dirty(changedKeys: keys)
        case (.dirty, .saved), (.dirty, .discarded):
            self = .clean
        default:
            break
        }
    }

    var hasUnsavedChanges: Bool {
        if case .dirty = self { return true }
        return false
    }
}

// MARK: - OnboardingFlowState（解 UE-P1#6 引导接新建会话）

enum OnboardingFlowState: UIState {

    case notStarted
    case step(Int)
    case promptCreateSession   // 第 3 步结束后，建议新建第一个会话
    case completed

    static var initial: OnboardingFlowState { .notStarted }

    enum Event: Sendable {
        case started
        case advancedToNextStep
        case skipped
        case createSessionRequested
        case finished
    }

    mutating func reduce(_ event: Event) {
        switch (self, event) {
        case (.notStarted, .started):
            self = .step(1)
        case (.step(let n), .advancedToNextStep) where n < 3:
            self = .step(n + 1)
        case (.step(3), .advancedToNextStep):
            self = .promptCreateSession
        case (_, .skipped), (_, .finished):
            self = .completed
        case (.promptCreateSession, .createSessionRequested):
            self = .completed
        default:
            break
        }
    }

    var currentStepIndex: Int {
        if case .step(let n) = self { return n }
        return 0
    }
}
