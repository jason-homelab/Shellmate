import Foundation

// W2 新增：UI 状态机基础协议（ADR-003）
// 所有"状态相关 UI 决策"从 state 派生，禁止用零散 Bool 组合表达

protocol UIState: Equatable, Sendable {
    associatedtype Event
    static var initial: Self { get }
    mutating func reduce(_ event: Event)
}

// 通用状态机包装：将 reduce 函数 + 当前 state 暴露给 SwiftUI
@MainActor
final class StateMachine<S: UIState>: ObservableObject {

    @Published private(set) var state: S

    init(initial: S = S.initial) {
        self.state = initial
    }

    func send(_ event: S.Event) {
        state.reduce(event)
    }
}
