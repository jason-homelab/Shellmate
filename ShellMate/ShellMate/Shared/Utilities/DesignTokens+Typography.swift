import SwiftUI

extension DesignTokens {

    enum Typography {

        // MARK: 欢迎界面 / 展示级
        static let heroHuge      = Font.system(size: 56, weight: .thin,     design: .rounded)
        static let heroXLarge    = Font.system(size: 52, weight: .thin,     design: .rounded)
        static let heroLarge     = Font.system(size: 48, weight: .thin,     design: .rounded)
        static let heroMedium    = Font.system(size: 40, weight: .light,    design: .rounded)
        static let heroSmall     = Font.system(size: 36, weight: .light,    design: .rounded)
        static let displayXLarge = Font.system(size: 32, weight: .light,    design: .rounded)
        static let displayLarge  = Font.system(size: 28, weight: .light,    design: .rounded)
        static let displayMedium = Font.system(size: 26, weight: .regular,  design: .rounded)
        static let displaySmall  = Font.system(size: 22, weight: .medium,   design: .rounded)
        static let displayXSmall = Font.system(size: 18, weight: .medium,   design: .rounded)

        // MARK: 标题级
        static let titleXLarge = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let titleLarge  = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let titlePanel  = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let titleMedium = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let titleSmall  = Font.system(size: 13, weight: .semibold, design: .rounded)

        // MARK: 正文级
        static let bodyLargeStrong  = Font.system(size: 14, weight: .semibold)
        static let bodyLargeMedium  = Font.system(size: 14, weight: .medium)
        static let bodyLarge        = Font.system(size: 14, weight: .regular)
        static let bodyMediumStrong = Font.system(size: 13, weight: .semibold)
        static let bodyMedium       = Font.system(size: 13, weight: .regular)
        static let bodySmallStrong  = Font.system(size: 12, weight: .semibold)
        static let bodySmall        = Font.system(size: 12, weight: .regular)

        // MARK: 标签级
        static let iconLarge     = Font.system(size: 16, weight: .regular)
        static let labelXLarge   = Font.system(size: 16, weight: .medium)
        static let labelLargeAlt = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let labelLargeMid = Font.system(size: 15, weight: .medium)
        static let labelLarge    = Font.system(size: 13, weight: .medium)
        static let labelMedium   = Font.system(size: 12, weight: .medium)
        static let labelSmall    = Font.system(size: 11, weight: .medium)

        // MARK: 说明文字级
        static let captionLarge        = Font.system(size: 11, weight: .regular)
        static let captionMedium       = Font.system(size: 10, weight: .regular)
        static let captionMediumStrong = Font.system(size: 10, weight: .medium)
        static let captionSmall        = Font.system(size: 9,  weight: .regular)
        static let captionSmallStrong  = Font.system(size: 9,  weight: .medium)

        // MARK: 等宽代码级
        static let codeLarge  = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let codeMedium = Font.system(size: 13, weight: .regular, design: .monospaced)
        static let codeSmall  = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let codeTiny   = Font.system(size: 11, weight: .regular, design: .monospaced)
    }
}
