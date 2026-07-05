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

    /// 对文本应用单条规则：单次前向扫描逐段拼接。
    /// 相比原「从后向前 replaceSubrange + 每次匹配重扫前缀」实现（O(匹配数×文本长度)），
    /// 本实现对间隙/片段各扫描一次并增量维护 ANSI 活动态，整体约 O(文本长度)，
    /// 行为与原实现逐字等价（见 HighlightEngineTests 特征化用例）。
    private func applyRule(
        regex: NSRegularExpression,
        color: HighlightColor,
        to text: String
    ) -> String {
        let ns = text as NSString
        let fullLength = ns.length
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: fullLength))
        guard !matches.isEmpty else { return text }

        let open = "\u{1B}[\(color.ansiFGCode)m"
        let reset = "\u{1B}[0m"

        var result = ""
        result.reserveCapacity(text.utf8.count + matches.count * (open.utf8.count + reset.utf8.count))

        var cursor = 0            // 已处理到的 UTF-16 位置
        var activeANSI = false    // 截至 cursor，原文是否处于尚未 reset 的 SGR 序列内

        for match in matches {
            let loc = match.range.location
            let len = match.range.length

            // 追加 [cursor, loc) 间隙，并据其中的 SGR 序列更新活动态
            if loc > cursor {
                let gap = ns.substring(with: NSRange(location: cursor, length: loc - cursor))
                result += gap
                activeANSI = Self.ansiStateAfter(scanning: gap, current: activeANSI)
            }

            let fragment = ns.substring(with: NSRange(location: loc, length: len))
            // 已含 ESC、或处于活动 ANSI 序列内 → 原样输出，避免破坏/双重高亮
            if activeANSI || fragment.contains("\u{1B}") {
                result += fragment
            } else {
                result += open
                result += fragment
                result += reset
            }
            // 片段自身可能含 SGR（正则命中 ESC 时），同步更新活动态
            activeANSI = Self.ansiStateAfter(scanning: fragment, current: activeANSI)
            cursor = loc + len
        }

        if cursor < fullLength {
            result += ns.substring(with: NSRange(location: cursor, length: fullLength - cursor))
        }
        return result
    }

    /// 扫描一段文本后的 ANSI 活动态：取其中最后一条 SGR 序列，
    /// 参数为空或 "0" 视为 reset（返回 false），否则处于活动色序列内（返回 true）；
    /// 段内无 SGR 时沿用传入的 current。语义与逐字符检查前缀等价。
    private static func ansiStateAfter(scanning segment: String, current: Bool) -> Bool {
        let ns = segment as NSString
        let hits = ansiDetectRegex.matches(in: segment, range: NSRange(location: 0, length: ns.length))
        guard let last = hits.last else { return current }
        let inner = NSRange(location: last.range.location + 2,
                            length: max(0, last.range.length - 3))
        let param = ns.substring(with: inner)
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
