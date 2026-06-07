import SwiftUI
import AppKit

// W1 新增：Semantic Token 命名空间
// 与 DesignTokens.Colors（原子层 / 品牌色）平级分离，承载语义化反馈、状态、隧道等用途
// 详见 docs/design-specs/W0_设计规格统一交付.md §1.1

extension DesignTokens {

    enum Semantic {

        // ── Feedback Info ────────────────────────────────────
        static let feedbackInfoFg     = Color(hex: "#077aff")
        static let feedbackInfoBg     = Color(hex: "#077aff").opacity(0.10)
        static let feedbackInfoBorder = Color(hex: "#077aff").opacity(0.22)

        // ── Feedback Success（与 statusConnected 区分语义） ───
        static let feedbackSuccessFg     = Color(hex: "#10b981")
        static let feedbackSuccessBg     = Color(hex: "#10b981").opacity(0.10)
        static let feedbackSuccessBorder = Color(hex: "#10b981").opacity(0.22)

        // ── Feedback Warn ────────────────────────────────────
        static let feedbackWarnFg     = Color(hex: "#f59e0b")
        static let feedbackWarnBg     = Color(hex: "#f59e0b").opacity(0.12)
        static let feedbackWarnBorder = Color(hex: "#f59e0b").opacity(0.26)

        // ── Feedback Error ───────────────────────────────────
        static let feedbackErrorFg     = Color(hex: "#ef4444")
        static let feedbackErrorBg     = Color(hex: "#ef4444").opacity(0.12)
        static let feedbackErrorBorder = Color(hex: "#ef4444").opacity(0.28)

        // ── Tunnel 类型语义色（替代 TunnelModels 硬编码） ────
        static let tunnelLocal  = Color(hex: "#7ab4f5")
        static let tunnelRemote = Color(hex: "#f5c842")
        static let tunnelSocks  = Color(hex: "#c88af0")

        // ── Focus Ring（W2 接入）─────────────────────────────
        static let focusRing = Color(hex: "#077aff")
    }
}

// 反馈等级枚举，供 FeedbackEvent 与 UI 共享
extension DesignTokens.Semantic {

    enum FeedbackLevel {
        case info
        case success
        case warn
        case error

        var fg: Color {
            switch self {
            case .info:    return DesignTokens.Semantic.feedbackInfoFg
            case .success: return DesignTokens.Semantic.feedbackSuccessFg
            case .warn:    return DesignTokens.Semantic.feedbackWarnFg
            case .error:   return DesignTokens.Semantic.feedbackErrorFg
            }
        }

        var bg: Color {
            switch self {
            case .info:    return DesignTokens.Semantic.feedbackInfoBg
            case .success: return DesignTokens.Semantic.feedbackSuccessBg
            case .warn:    return DesignTokens.Semantic.feedbackWarnBg
            case .error:   return DesignTokens.Semantic.feedbackErrorBg
            }
        }

        var border: Color {
            switch self {
            case .info:    return DesignTokens.Semantic.feedbackInfoBorder
            case .success: return DesignTokens.Semantic.feedbackSuccessBorder
            case .warn:    return DesignTokens.Semantic.feedbackWarnBorder
            case .error:   return DesignTokens.Semantic.feedbackErrorBorder
            }
        }

        var sfSymbol: String {
            switch self {
            case .info:    return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warn:    return "exclamationmark.triangle.fill"
            case .error:   return "xmark.octagon.fill"
            }
        }
    }
}
