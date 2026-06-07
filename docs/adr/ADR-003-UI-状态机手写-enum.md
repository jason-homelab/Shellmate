# ADR-003：UI 状态机手写 enum 而非引入 TCA / Combine Reducer

**状态**：已采纳
**日期**：2026-06-07

## 背景

5 个关键 UI 状态机（TerminalConnection / TabLifecycle / OnboardingFlow / AIConsent / SettingsDirty）需选定建模方式。

## 决策

**手写 enum + reduce 函数**。不引入 TCA、Combine Reducer 或 third-party state machine 库。

```swift
public enum TerminalConnectionState: Equatable {
    case idle
    case connecting(ConnectStage)
    case connected(since: Date)
    // ...

    public mutating func reduce(_ event: Event) { ... }
}
```

## 理由

1. **零依赖**：避免 TCA 的学习曲线与版本绑定风险
2. **可调试**：纯 enum 在 Xcode debugger 中可读
3. **易单测**：`XCTAssertEqual(state, .connected)` 直接断言
4. **足够强大**：5 个状态机均不超过 10 态，无需 effect 系统
5. **Swift 原生**：Sendable / Codable / pattern matching 直接可用

## 后果

- ✅ 团队成员 30 分钟可上手
- ✅ 单测覆盖率天然 ≥ 80%
- ⚠️ 复杂 effect 编排（如 retry 倒计时）需配合 actor，不在状态机内
