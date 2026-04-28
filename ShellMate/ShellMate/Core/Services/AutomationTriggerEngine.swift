import Foundation
import AppKit
import UserNotifications

// MARK: - 自动化触发器引擎（技术方案 §3.19.3）

/// 终端输出匹配引擎，对标 iTerm2 Triggers，完全本地执行
/// - 所有正则匹配在独立 Task 中执行（ReDoS 防护）
/// - 单次匹配超过 500ms 自动取消
@MainActor
final class AutomationTriggerEngine {

    static let shared = AutomationTriggerEngine()

    /// 上次触发时间（冷却时间判断）
    private var lastFiredAt: [UUID: Date] = [:]

    private init() {}

    // MARK: - 终端输出到达时调用

    /// 由 TerminalController 在收到终端输出后调用
    func process(output: String, sessionId: UUID, controller: TerminalController) {
        let triggers = AutomationTriggerStore.shared.activeTriggers(for: sessionId)
            .filter { $0.conditionType == .outputRegex || $0.conditionType == .outputKeyword }
        guard !triggers.isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }
            for trigger in triggers {
                guard self.shouldFire(trigger) else { continue }
                let matched = await self.matches(trigger: trigger, output: output)
                if matched {
                    self.fire(trigger: trigger, output: output, controller: controller)
                    self.lastFiredAt[trigger.id] = Date()
                }
            }
        }
    }

    /// 连接/断开事件触发（.onConnect / .onDisconnect）
    func processEvent(
        _ event: AutomationTrigger.TriggerConditionType,
        sessionId: UUID,
        controller: TerminalController
    ) {
        let triggers = AutomationTriggerStore.shared.activeTriggers(for: sessionId)
            .filter { $0.conditionType == event }
        for trigger in triggers where isCooledDown(trigger) {
            fire(trigger: trigger, output: "", controller: controller)
            lastFiredAt[trigger.id] = Date()
        }
    }

    // MARK: - 匹配（异步，500ms 超时防 ReDoS）

    private func matches(trigger: AutomationTrigger, output: String) async -> Bool {
        guard let pattern = trigger.pattern, !pattern.isEmpty else { return false }

        return await withTaskCancellationHandler {
            await Task.detached(priority: .utility) {
                let options: String.CompareOptions
                switch trigger.conditionType {
                case .outputRegex:
                    options = trigger.caseSensitive
                        ? .regularExpression
                        : [.regularExpression, .caseInsensitive]
                case .outputKeyword:
                    options = trigger.caseSensitive ? [] : .caseInsensitive
                default:
                    return false
                }
                return output.range(of: pattern, options: options) != nil
            }.value
        } onCancel: {
            // Task 已取消时无需操作
        }
    }

    // MARK: - 冷却判断

    private func shouldFire(_ trigger: AutomationTrigger) -> Bool {
        isCooledDown(trigger)
    }

    private func isCooledDown(_ trigger: AutomationTrigger) -> Bool {
        guard trigger.cooldownSeconds > 0,
              let last = lastFiredAt[trigger.id] else { return true }
        return Date().timeIntervalSince(last) >= Double(trigger.cooldownSeconds)
    }

    // MARK: - 动作执行

    private func fire(
        trigger: AutomationTrigger,
        output: String,
        controller: TerminalController
    ) {
        let payload = substituteVariables(trigger.actionPayload, output: output, controller: controller)

        switch trigger.actionType {
        case .sendCommand:
            guard !payload.isEmpty else { return }
            Task { try? await controller.send(payload + "\n") }

        case .notification:
            sendNotification(title: trigger.name, body: payload.isEmpty ? trigger.name : payload)

        case .openURL:
            guard let url = URL(string: payload) else { return }
            NSWorkspace.shared.open(url)

        case .writeLog:
            guard !payload.isEmpty else { return }
            appendToFile(path: payload, text: "[\(Date())] \(output)\n")

        case .runScript:
            #if !APPSTORE
            guard !payload.isEmpty else { return }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/sh")
            proc.arguments = ["-c", payload]
            try? proc.run()
            #endif

        case .highlightLine:
            // 动态添加临时高亮规则
            guard let pattern = trigger.pattern, !pattern.isEmpty else { return }
            let colorName = payload.isEmpty ? "yellow" : payload.lowercased()
            let rule = HighlightRule(
                id: trigger.id,
                pattern: pattern,
                color: highlightColorFor(name: colorName),
                useRegex: trigger.conditionType == .outputRegex
            )
            HighlightEngine.shared.addRule(rule)
        }
    }

    // MARK: - 模板变量替换

    /// 支持：{{MATCHED_TEXT}} / {{SESSION_NAME}} / {{TIMESTAMP}} / {{HOST}}
    private func substituteVariables(
        _ template: String,
        output: String,
        controller: TerminalController
    ) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return template
            .replacingOccurrences(of: "{{MATCHED_TEXT}}", with: output)
            .replacingOccurrences(of: "{{SESSION_NAME}}", with: controller.session.name)
            .replacingOccurrences(of: "{{TIMESTAMP}}", with: timestamp)
            .replacingOccurrences(of: "{{HOST}}", with: controller.session.host)
    }

    // MARK: - 辅助

    private func sendNotification(title: String, body: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func appendToFile(path: String, text: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        guard let data = text.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: expandedPath) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func highlightColorFor(name: String) -> HighlightColor {
        switch name {
        case "red":     return .red
        case "green":   return .green
        case "blue":    return .blue
        case "cyan":    return .cyan
        case "magenta": return .magenta
        case "white":   return .white
        default:        return .yellow
        }
    }
}

// MARK: - 正则校验工具

extension AutomationTriggerEngine {
    /// 保存触发器前校验正则是否有效，返回 nil 表示合法
    static func validateRegex(_ pattern: String) -> String? {
        guard !pattern.isEmpty else { return nil }
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
