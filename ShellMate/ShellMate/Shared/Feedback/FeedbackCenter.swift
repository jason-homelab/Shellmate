import SwiftUI
import Combine
import Foundation

// W1 新增：Feedback 全局中枢（ADR-002）
// @MainActor + ObservableObject，承担 Toast / Banner / 系统通知派发

@MainActor
final class FeedbackCenter: ObservableObject {

    static let shared = FeedbackCenter()

    @Published private(set) var activeToasts: [FeedbackEvent] = []
    @Published private(set) var activeBanners: [FeedbackEvent.BannerSlot: FeedbackEvent] = [:]

    private static let maxToastStack = 3
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    // ── 派发入口 ──────────────────────────────────────────
    func present(_ event: FeedbackEvent) {
        switch event.channel {
        case .toast:
            presentToast(event)
        case .banner(let slot):
            presentBanner(event, slot: slot)
        case .systemNotification:
            SystemNotificationBridge.shared.post(event)
        }
    }

    // ── Toast 队列管理 ────────────────────────────────────
    private func presentToast(_ event: FeedbackEvent) {
        if activeToasts.count >= Self.maxToastStack {
            if let oldest = activeToasts.first {
                dismiss(id: oldest.id)
            }
        }
        activeToasts.append(event)
        scheduleAutoDismiss(event)
    }

    // ── Banner 槽位（每 slot 互斥）─────────────────────────
    private func presentBanner(_ event: FeedbackEvent, slot: FeedbackEvent.BannerSlot) {
        activeBanners[slot] = event
        scheduleAutoDismiss(event)
    }

    // ── 显式关闭 ──────────────────────────────────────────
    func dismiss(id: UUID) {
        activeToasts.removeAll { $0.id == id }
        for (slot, banner) in activeBanners where banner.id == id {
            activeBanners.removeValue(forKey: slot)
        }
        dismissTasks[id]?.cancel()
        dismissTasks.removeValue(forKey: id)
    }

    func dismissBanner(slot: FeedbackEvent.BannerSlot) {
        if let banner = activeBanners[slot] {
            dismiss(id: banner.id)
        }
    }

    func clearAll() {
        for task in dismissTasks.values { task.cancel() }
        dismissTasks.removeAll()
        activeToasts.removeAll()
        activeBanners.removeAll()
    }

    // ── 自动消失定时器 ────────────────────────────────────
    private func scheduleAutoDismiss(_ event: FeedbackEvent) {
        if case .auto(let interval) = event.lifetime {
            let id = event.id
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled {
                    self?.dismiss(id: id)
                }
            }
            dismissTasks[id] = task
        }
    }

    // ── 触发恢复 Action ───────────────────────────────────
    func performAction(_ action: FeedbackAction, dismissingEventId eventId: UUID? = nil) {
        Task {
            await action.handler()
            if let eventId = eventId {
                dismiss(id: eventId)
            }
        }
    }
}
