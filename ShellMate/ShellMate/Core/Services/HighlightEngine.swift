import Foundation

// MARK: - 高亮颜色

/// 终端高亮颜色（ANSI SGR 前景色）
enum HighlightColor: String, CaseIterable, Codable {
    case red     = "红色"
    case yellow  = "黄色"
    case green   = "绿色"
    case cyan    = "青色"
    case magenta = "洋红"
    case blue    = "蓝色"
    case white   = "白色"

    /// ANSI SGR 前景色代码
    var ansiFGCode: String {
        switch self {
        case .red:     return "31"
        case .yellow:  return "33"
        case .green:   return "32"
        case .cyan:    return "36"
        case .magenta: return "35"
        case .blue:    return "34"
        case .white:   return "37"
        }
    }
}

// MARK: - 高亮规则

/// 终端关键字高亮规则
struct HighlightRule: Identifiable, Codable {
    var id: UUID
    /// 匹配模式（字面字符串或正则表达式）
    var pattern: String
    /// 高亮颜色
    var color: HighlightColor
    /// 是否启用
    var enabled: Bool
    /// 是否使用正则表达式
    var useRegex: Bool

    init(
        id: UUID = UUID(),
        pattern: String,
        color: HighlightColor = .yellow,
        enabled: Bool = true,
        useRegex: Bool = false
    ) {
        self.id = id
        self.pattern = pattern
        self.color = color
        self.enabled = enabled
        self.useRegex = useRegex
    }

    /// 默认预置规则
    static var defaults: [HighlightRule] {
        [
            HighlightRule(pattern: "error",   color: .red,    useRegex: false),
            HighlightRule(pattern: "ERROR",   color: .red,    useRegex: false),
            HighlightRule(pattern: "warning", color: .yellow, useRegex: false),
            HighlightRule(pattern: "WARN",    color: .yellow, useRegex: false),
            HighlightRule(pattern: "success", color: .green,  useRegex: false),
            HighlightRule(pattern: "failed",  color: .red,    useRegex: false),
        ]
    }
}

// MARK: - 高亮引擎

/// 终端关键字高亮引擎
/// 向 SSH 数据流注入 ANSI SGR 颜色转义序列，实现关键字高亮
@MainActor
final class HighlightEngine: ObservableObject {

    static let shared = HighlightEngine()

    @Published var rules: [HighlightRule] = [] {
        didSet { recompile(); save() }
    }

    @Published var isEnabled: Bool = true {
        didSet { save() }
    }

    /// 预编译的正则表达式缓存
    private var compiled: [(regex: NSRegularExpression, color: HighlightColor)] = []

    /// 检测已有 ANSI 序列所用的正则（类级预编译，避免重复构建）
    private static let ansiDetectRegex = try! NSRegularExpression(pattern: "\u{1B}\\[[0-9;]*m")

    private let rulesKey   = "HighlightEngine.rules"
    private let enabledKey = "HighlightEngine.enabled"

    private init() {
        load()
    }

    // MARK: - 规则管理

    func addRule(_ rule: HighlightRule) {
        rules.append(rule)
    }

    func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
    }

    func updateRule(_ rule: HighlightRule) {
        if let i = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[i] = rule
        }
    }

    // MARK: - 数据处理

    /// 处理终端字节数据：向匹配关键字注入 ANSI 高亮序列
    /// - Parameter data: 原始 SSH 数据
    /// - Returns: 注入高亮序列后的数据（若未启用则原样返回）
    func process(_ data: Data) -> Data {
        guard isEnabled, !compiled.isEmpty else { return data }
        guard let text = String(data: data, encoding: .utf8) else { return data }
        var result = text
        for (regex, color) in compiled {
            result = applyRule(regex: regex, color: color, to: result)
        }
        return result.data(using: .utf8) ?? data
    }

    // MARK: - 私有

    /// 对文本应用单条规则：从后向前替换以避免偏移漂移
    private func applyRule(
        regex: NSRegularExpression,
        color: HighlightColor,
        to text: String
    ) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range).reversed()
        var result = text
        for match in matches {
            guard let swiftRange = Range(match.range, in: result) else { continue }
            let fragment = String(result[swiftRange])
            // 跳过已含 ESC 的片段，避免双重高亮损坏 ANSI 序列
            guard !fragment.contains("\u{1B}") else { continue }
            // 跳过已处于活动 ANSI 颜色序列内部的匹配
            guard !isInsideActiveANSI(result, before: swiftRange.lowerBound) else { continue }
            result.replaceSubrange(
                swiftRange,
                with: "\u{1B}[\(color.ansiFGCode)m\(fragment)\u{1B}[0m"
            )
        }
        return result
    }

    /// 判断 text 中 index 之前是否处于一个尚未 reset 的 ANSI 颜色序列内
    /// 取 prefix 中最后一条 ANSI SGR 序列：若参数为空或 "0" 表示 reset（不在序列内），否则在序列内。
    private func isInsideActiveANSI(_ text: String, before index: String.Index) -> Bool {
        let prefix = String(text[text.startIndex..<index])
        let nsPrefix = prefix as NSString
        let range = NSRange(location: 0, length: nsPrefix.length)
        let hits = Self.ansiDetectRegex.matches(in: prefix, range: range)
        guard let last = hits.last else { return false }
        // 提取 SGR 参数（ESC [ <params> m 中的 <params>）
        let inner = NSRange(location: last.range.location + 2,
                            length: max(0, last.range.length - 3))
        let param = nsPrefix.substring(with: inner)
        return param != "0" && !param.isEmpty
    }

    /// 重新编译所有规则
    private func recompile() {
        compiled = rules.compactMap { rule in
            guard rule.enabled, !rule.pattern.isEmpty else { return nil }
            let pat = rule.useRegex
                ? rule.pattern
                : NSRegularExpression.escapedPattern(for: rule.pattern)
            guard let regex = try? NSRegularExpression(pattern: pat, options: []) else {
                return nil
            }
            return (regex: regex, color: rule.color)
        }
    }

    // MARK: - 持久化

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)
    }

    private func load() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let saved = try? JSONDecoder().decode([HighlightRule].self, from: data) {
            rules = saved
        } else {
            rules = HighlightRule.defaults
        }
    }
}
