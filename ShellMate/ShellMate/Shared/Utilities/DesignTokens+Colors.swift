import SwiftUI
import AppKit

extension DesignTokens {

    enum Colors {

        private static func adaptive(light: NSColor, dark: NSColor) -> Color {
            Color(nsColor: NSColor(name: nil) { traits in
                traits.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            })
        }

        // ── Void 四层表面系统（深色优先）────────────────────────

        static let surfaceWindow = adaptive(
            light: NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1),
            dark:  NSColor(srgbRed: 0.027, green: 0.039, blue: 0.067, alpha: 1)
        )
        static let surfacePanel = adaptive(
            light: NSColor(srgbRed: 0.910, green: 0.910, blue: 0.929, alpha: 1),
            dark:  NSColor(srgbRed: 0.051, green: 0.067, blue: 0.090, alpha: 1)
        )
        static let surfaceCard = adaptive(
            light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
            dark:  NSColor(srgbRed: 0.086, green: 0.110, blue: 0.157, alpha: 1)  // #161C28，较 surfacePanel 亮约 10 点
        )
        static let surfaceOverlay = adaptive(
            light: NSColor(srgbRed: 0.953, green: 0.957, blue: 0.969, alpha: 1),
            dark:  NSColor(srgbRed: 0.102, green: 0.133, blue: 0.196, alpha: 1)
        )
        static let surfaceInput = adaptive(
            light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
            dark:  NSColor(srgbRed: 0.078, green: 0.094, blue: 0.149, alpha: 1)
        )

        // ── 玻璃覆层 ──────────────────────────────────────────

        static let glassUltraLight = adaptive(light: NSColor(white: 0.0, alpha: 0.02), dark: NSColor(white: 1.0, alpha: 0.03))
        static let glassLight      = adaptive(light: NSColor(white: 0.0, alpha: 0.03), dark: NSColor(white: 1.0, alpha: 0.04))
        static let glassMedium     = adaptive(light: NSColor(white: 0.0, alpha: 0.05), dark: NSColor(white: 1.0, alpha: 0.06))
        static let glassHoverColor = adaptive(light: NSColor(white: 0.0, alpha: 0.03), dark: NSColor(white: 1.0, alpha: 0.04))
        static let surfaceHover    = adaptive(light: NSColor(white: 0.0, alpha: 0.05), dark: NSColor(white: 1.0, alpha: 0.05))
        static let glassPress      = adaptive(light: NSColor(white: 0.0, alpha: 0.07), dark: NSColor(white: 1.0, alpha: 0.07))
        static let glassPressStrong = adaptive(light: NSColor(white: 0.0, alpha: 0.10), dark: NSColor(white: 1.0, alpha: 0.10))
        static let glassSelected   = Color(hex: "#077aff").opacity(0.12)

        // ── 玻璃边框 ──────────────────────────────────────────

        static let glassBorderTop    = adaptive(light: NSColor(white: 0.0, alpha: 0.08), dark: NSColor(white: 1.0, alpha: 0.10))
        static let glassBorderSide   = adaptive(light: NSColor(white: 0.0, alpha: 0.05), dark: NSColor(white: 1.0, alpha: 0.07))
        static let glassBorderBottom = adaptive(light: NSColor(white: 0.0, alpha: 0.03), dark: NSColor(white: 1.0, alpha: 0.04))
        static let glassBorderAccent = Color(hex: "#077aff").opacity(0.30)

        // ── 品牌色：Apple Blue ────────────────────────────────

        static let accentPrimary    = Color(hex: "#077aff")
        static let accentSecondary  = Color(hex: "#34d399")
        static let accentTertiary   = Color(hex: "#0051d5")
        static let accentGlow       = Color(hex: "#077aff").opacity(0.20)
        static let accentGlowStrong = Color(hex: "#077aff").opacity(0.38)

        // ── AI 品牌色：Apple Indigo ───────────────────────────

        static let accentAI     = Color(hex: "#818cf8")
        static let accentAIGlow = Color(hex: "#818cf8").opacity(0.25)
        static let accentIndigo = Color(hex: "#5856d6")

        // ── 脚本自动化色 ──────────────────────────────────────

        static let accentScript = Color(hex: "#fb923c")

        // ── 文字色（Void 冷白系）─────────────────────────────

        static let textPrimary = adaptive(
            light: NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1),
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 1)
        )
        static let textSecondary = adaptive(
            light: NSColor(srgbRed: 0.420, green: 0.420, blue: 0.443, alpha: 1),
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.52)
        )
        static let textTertiary = adaptive(
            light: NSColor(srgbRed: 0.682, green: 0.682, blue: 0.698, alpha: 1),
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.30)
        )
        static let textDisabled = adaptive(
            light: NSColor(srgbRed: 0.780, green: 0.780, blue: 0.800, alpha: 1),
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.18)
        )
        static let textSubtle = adaptive(
            light: NSColor(srgbRed: 0.557, green: 0.557, blue: 0.576, alpha: 1),
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.40)
        )

        // ── 状态色 ────────────────────────────────────────────

        static let statusConnected = adaptive(
            light: NSColor(srgbRed: 0.204, green: 0.831, blue: 0.600, alpha: 1),
            dark:  NSColor(srgbRed: 0.204, green: 0.831, blue: 0.600, alpha: 1)
        )
        static let statusConnecting = adaptive(
            light: NSColor(srgbRed: 1.000, green: 0.584, blue: 0.000, alpha: 1),
            dark:  NSColor(srgbRed: 0.984, green: 0.749, blue: 0.141, alpha: 1)
        )
        static let statusError = adaptive(
            light: NSColor(srgbRed: 1.000, green: 0.231, blue: 0.188, alpha: 1),
            dark:  NSColor(srgbRed: 0.973, green: 0.443, blue: 0.443, alpha: 1)
        )
        static let statusOffline = adaptive(
            light: NSColor(srgbRed: 0.557, green: 0.557, blue: 0.576, alpha: 1),
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.28)
        )

        // ── 边框 ──────────────────────────────────────────────

        static let borderPrimary = adaptive(
            light: NSColor(srgbRed: 0.824, green: 0.824, blue: 0.847, alpha: 0.5),
            dark:  NSColor(white: 1.0, alpha: 0.07)
        )
        static let borderSecondary = adaptive(
            light: NSColor(srgbRed: 0.824, green: 0.824, blue: 0.847, alpha: 0.3),
            dark:  NSColor(white: 1.0, alpha: 0.05)
        )
        static let borderFocus  = Color(hex: "#077aff").opacity(0.35)
        static let borderSubtle = adaptive(
            light: NSColor(srgbRed: 0.824, green: 0.824, blue: 0.847, alpha: 0.2),
            dark:  NSColor(white: 1.0, alpha: 0.04)
        )

        // ── 背景交互状态 ──────────────────────────────────────

        static let backgroundHover    = adaptive(light: NSColor(white: 0.0, alpha: 0.04), dark: NSColor(white: 1.0, alpha: 0.04))
        static let backgroundSelected = Color(hex: "#077aff").opacity(0.12)
        static let backgroundPressed  = Color(hex: "#077aff").opacity(0.18)

        // ── 扩展令牌（兼容旧调用）────────────────────────────

        static let surfaceElevated   = surfaceCard
        static let surfaceToolbar    = surfacePanel
        static let borderDefault     = borderPrimary
        static let borderFaint       = borderSecondary
        static let terminalBackground    = Color(hex: "#0d1117")
        static let terminalText          = textPrimary
        static let terminalPreviewBg     = Color(hex: "#070a11")
        static let terminalPromptDefault = Color(hex: "#00d4aa")

        static let surfaceActive = adaptive(
            light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.92),
            dark:  NSColor(srgbRed: 0.000, green: 0.478, blue: 1.000, alpha: 0.07)
        )

        static let iconPrimary   = textSecondary
        static let iconSecondary = textTertiary

        static let codeBackground = Color(hex: "#070a11")
        static let codeText       = Color(hex: "#00d4aa").opacity(0.75)

        static let danger = statusError
    }
}
