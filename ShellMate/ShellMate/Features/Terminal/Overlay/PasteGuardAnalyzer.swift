import Foundation

// W5 新增：粘贴内容危险性分析器
// 与 PasteGuardOverlay 解耦，便于单测

struct PasteGuardRequest: Identifiable, Equatable {
    let id = UUID()
    let level: GuardLevel
    let originalContent: String
    let preview: String              // 截断后的预览（避免巨型内容渲染卡顿）
    let lineCount: Int
    let charCount: Int
    let flaggedTokens: [String]

    enum GuardLevel: Equatable {
        case multiline               // 仅多行
        case largeContent            // 超 1000 行
        case danger                  // 命中危险关键词

        var title: String {
            switch self {
            case .multiline:    return "多行内容粘贴"
            case .largeContent: return "粘贴内容较大"
            case .danger:       return "检测到危险命令"
            }
        }

        var description: String {
            switch self {
            case .multiline:
                return "你即将向终端粘贴多行内容。多行粘贴可能触发自动执行（含换行符），请确认内容无误。"
            case .largeContent:
                return "粘贴内容超过 1000 行。粘贴大量内容可能导致终端卡顿，并且部分命令会立即执行。"
            case .danger:
                return "粘贴内容包含可能造成数据丢失或系统损坏的命令。请仔细阅读后确认。"
            }
        }
    }
}

enum PasteGuardAnalyzer {

    // 危险关键词清单（保守，避免误杀；可在设置中扩展）
    static let dangerPatterns: [String] = [
        "rm -rf /",
        "rm -rf ~",
        "rm -rf *",
        ":(){:|:&};:",          // fork bomb
        "mkfs.",
        "dd if=",
        "> /dev/sda",
        "chmod -R 777 /",
        "shutdown -h",
        "reboot now",
        "halt now",
        "killall -9",
        "curl | sh",
        "curl | bash",
        "wget | sh",
        "wget | bash"
    ]

    static let maxPreviewChars = 1200
    static let largeContentLineThreshold = 1000

    /// 分析粘贴内容，返回需弹守护时的 request；不需要时返回 nil
    static func analyze(_ content: String) -> PasteGuardRequest? {
        let lines = content.components(separatedBy: .newlines)
        let lineCount = lines.count
        let charCount = content.count

        // 命中危险关键词 — 最高级别
        let flagged = dangerPatterns.filter { content.contains($0) }
        if !flagged.isEmpty {
            return PasteGuardRequest(
                level: .danger,
                originalContent: content,
                preview: makePreview(content),
                lineCount: lineCount,
                charCount: charCount,
                flaggedTokens: flagged
            )
        }

        // 超大粘贴
        if lineCount > largeContentLineThreshold {
            return PasteGuardRequest(
                level: .largeContent,
                originalContent: content,
                preview: makePreview(content),
                lineCount: lineCount,
                charCount: charCount,
                flaggedTokens: []
            )
        }

        // 多行（>= 2 行且总长度 > 100 字符）
        if lineCount > 1 && charCount > 100 {
            return PasteGuardRequest(
                level: .multiline,
                originalContent: content,
                preview: makePreview(content),
                lineCount: lineCount,
                charCount: charCount,
                flaggedTokens: []
            )
        }

        return nil
    }

    private static func makePreview(_ content: String) -> String {
        if content.count <= maxPreviewChars {
            return content
        }
        let index = content.index(content.startIndex, offsetBy: maxPreviewChars)
        return String(content[..<index]) + "\n\n…（已截断，共 \(content.count) 字符）"
    }
}
