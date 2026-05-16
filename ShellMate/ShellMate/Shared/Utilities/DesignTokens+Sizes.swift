import CoreFoundation

extension DesignTokens {

    enum Sizes {
        static let sidebarWidth:    CGFloat = 238
        static let sidebarMinWidth: CGFloat = 238
        static let sidebarMaxWidth: CGFloat = 320

        static let sessionRowHeight: CGFloat = 44
        static let groupRowHeight:   CGFloat = 36

        static let statusDotSize:       CGFloat = 6
        static let statusDotGlowRadius: CGFloat = 6

        static let buttonHeight:   CGFloat = 28
        static let buttonMinWidth: CGFloat = 80
        static let iconButtonSize: CGFloat = 28

        static let avatarSizeSmall:  CGFloat = 26
        static let avatarSizeMedium: CGFloat = 34
        static let avatarSizeLarge:  CGFloat = 52

        // 圆角（radius-sm:6  radius-md:8  radius-xl:12  radius-2xl:16  radius-3xl:24）
        static let cornerRadiusTiny:    CGFloat = 2
        static let cornerRadiusMicro:   CGFloat = 3
        static let cornerRadiusXXSmall: CGFloat = 4
        static let cornerRadiusXSmall:  CGFloat = 6
        static let cornerRadiusSmall:   CGFloat = 8
        static let cornerRadiusMedium:  CGFloat = 12
        static let cornerRadiusLarge:   CGFloat = 16
        static let cornerRadiusXLarge:  CGFloat = 20
        static let cornerRadiusPanel:   CGFloat = 24
        static let cornerRadiusFull:    CGFloat = 9999

        static let sheetWidth:     CGFloat = 540
        static let sheetMinHeight: CGFloat = 420

        static let toolbarHeight:      CGFloat = 48
        static let tabBarHeight:       CGFloat = 36
        static let tabMinWidth:        CGFloat = 100
        static let tabMaxWidth:        CGFloat = 200
        static let tabCloseButtonSize: CGFloat = 16

        static let statusBarHeight:     CGFloat = 32
        static let sidebarFooterHeight: CGFloat = 31

        static let aiPanelWidth:   CGFloat = 380
        static let sftpPanelWidth: CGFloat = 480

        static let terminalFontSizeMin: CGFloat = 9
        static let terminalFontSizeMax: CGFloat = 24

        static let sessionIconSize: CGFloat = 32
    }
}
