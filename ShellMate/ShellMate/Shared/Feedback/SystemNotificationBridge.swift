import Foundation
import SwiftUI
import UserNotifications

// W1 新增：桥接 UNUserNotificationCenter
// 用于"用户切换 App 时发生重要事件"的场景（解 UE-P1#9 网络断开通知）

@MainActor
final class SystemNotificationBridge {

    static let shared = SystemNotificationBridge()

    private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async {
        guard authorizationStatus == .notDetermined else { return }
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
        } catch {
            AppLogger.ui.warning("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func post(_ event: FeedbackEvent) {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            AppLogger.ui.info("System notification skipped, not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = localizedString(event.title)
        if let message = event.message {
            content.body = localizedString(message)
        }
        content.sound = (event.level == .error) ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Task { @MainActor in
                    AppLogger.ui.warning("Notification post failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func localizedString(_ key: LocalizedStringKey) -> String {
        // SwiftUI LocalizedStringKey 在运行时可通过 reflection 取出原始 key 字符串
        let mirror = Mirror(reflecting: key)
        if let keyString = mirror.children.first(where: { $0.label == "key" })?.value as? String {
            return NSLocalizedString(keyString, comment: "")
        }
        return ""
    }
}
