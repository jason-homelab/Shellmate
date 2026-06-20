import SwiftUI
import AppKit

// W1 新增：Elevation Token 命名空间
// 5 级阴影系统 e0-e4，承载 flat / 卡片 / 浮起按钮 / Toast / Modal 的层级语言
// 深色模式下传统阴影不可见，自动叠加内描边补偿
// 详见 docs/design-specs/W0_设计规格统一交付.md §1.2

extension DesignTokens {

    enum Elevation {

        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        static let e0 = Shadow(color: .clear, radius: 0, x: 0, y: 0)

        static let e1 = Shadow(
            color: Color.black.opacity(0.06),
            radius: 2, x: 0, y: 1
        )

        static let e2 = Shadow(
            color: Color.black.opacity(0.10),
            radius: 6, x: 0, y: 2
        )

        static let e3 = Shadow(
            color: Color.black.opacity(0.18),
            radius: 24, x: 0, y: 8
        )

        static let e4 = Shadow(
            color: Color.black.opacity(0.32),
            radius: 64, x: 0, y: 24
        )

        // 深色模式补偿色（内描边）
        static let darkModeInnerBorder      = Color.white.opacity(0.06)
        static let darkModeInnerBorderStrong = Color.white.opacity(0.10)
    }
}

// SwiftUI 便捷 modifier，一行接入 elevation
extension View {

    func elevation(_ shadow: DesignTokens.Elevation.Shadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}
