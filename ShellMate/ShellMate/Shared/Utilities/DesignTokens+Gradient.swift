import SwiftUI

// W1 新增：扩展现有 DesignTokens.Gradients
// 承载 Welcome 径向渐变 / AI 按钮线性渐变等命名渐变
// 详见 docs/design-specs/W0_设计规格统一交付.md §1.3

extension DesignTokens.Gradients {

    // ── Welcome 径向渐变 3 色 ────────────────────────────
    static let welcomeStart = Color(hex: "#4299fd")
    static let welcomeMid   = Color(hex: "#7eb7fb")
    static let welcomeEnd   = Color(hex: "#bad6f9")

    static let welcomeRadial = RadialGradient(
        gradient: SwiftUI.Gradient(colors: [
            welcomeStart.opacity(0.18),
            welcomeMid.opacity(0.10),
            welcomeEnd.opacity(0.04),
            .clear
        ]),
        center: .top,
        startRadius: 80,
        endRadius: 640
    )

    // ── AI 按钮线性渐变 135°（与现有 aiGradient 区分用途） ─
    static let aiButtonStart = Color(hex: "#818cf8")
    static let aiButtonEnd   = Color(hex: "#5856d6")

    static let aiButton = LinearGradient(
        gradient: SwiftUI.Gradient(colors: [aiButtonStart, aiButtonEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let aiIcon = LinearGradient(
        gradient: SwiftUI.Gradient(colors: [aiButtonStart, aiButtonEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
