# ADR-002：FeedbackCenter 采用 @MainActor actor

**状态**：已采纳
**日期**：2026-06-07
**决策者**：Tech Lead

## 背景

新引入的 Feedback 中枢需要承担：跨 Feature 的 Toast / Banner / 系统通知派发。可选实现：
1. `ObservableObject` + `@Published`
2. `@MainActor actor`
3. 全局单例 + Combine `PassthroughSubject`

## 决策

采用 **`@MainActor actor`** 模式。

```swift
@MainActor
public final class FeedbackCenter: ObservableObject {
    public static let shared = FeedbackCenter()
    @Published private(set) var activeToasts: [FeedbackEvent] = []
    @Published private(set) var activeBanner: FeedbackEvent?

    public func present(_ event: FeedbackEvent) async { ... }
    public func dismiss(_ id: UUID) { ... }
}
```

## 理由

1. **MainActor 保证 UI 安全**：Toast/Banner 是纯 UI 状态，必须主线程访问
2. **actor 保证状态一致**：多个 Service 并发触发反馈时无竞态
3. **ObservableObject 桥接 SwiftUI**：业务侧 `@EnvironmentObject` 即可观察
4. **拒绝 Combine Subject**：会出现订阅者重复 / 漏接，调试困难

## 后果

- ✅ Service 层 `await FeedbackCenter.shared.present(...)` 即可触发
- ✅ SwiftUI 自动重渲染
- ⚠️ 必须遵守 `async` 调用约束
