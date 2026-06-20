import SwiftUI

// W1 新增：Typography mono 子命名空间
// 数据展示场景的等宽体节奏（StatusBar 数字 / SFTP 字节 / Preflight 耗时）
// 详见 docs/design-specs/W0_设计规格统一交付.md §1.4

extension DesignTokens.Typography {

    enum Mono {

        static let code = Font.system(
            size: 13, weight: .regular, design: .monospaced
        )

        static let dataXS = Font.system(
            size: 11, weight: .regular, design: .monospaced
        )

        static let dataSM = Font.system(
            size: 12, weight: .regular, design: .monospaced
        )

        static let label = Font.system(
            size: 11, weight: .semibold, design: .monospaced
        )
    }
}
