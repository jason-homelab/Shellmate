import SwiftUI

extension Color {
    /// 从十六进制字符串创建颜色
    /// - Parameter hex: 十六进制颜色字符串，支持 #RGB、#RRGGBB、#RRGGBBAA 格式
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// 将颜色转换为十六进制字符串
    /// - Returns: 十六进制颜色字符串（#RRGGBB 格式）
    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else {
            return "#000000"
        }

        let r: CGFloat = components.count >= 1 ? components[0] : 0
        let g: CGFloat = components.count >= 2 ? components[1] : 0
        let b: CGFloat = components.count >= 3 ? components[2] : 0

        return String(
            format: "#%02lX%02lX%02lX",
            lround(Double(r * 255)),
            lround(Double(g * 255)),
            lround(Double(b * 255))
        )
    }

    /// 调整颜色亮度
    /// - Parameter amount: 亮度调整量（正数变亮，负数变暗）
    func adjustBrightness(by amount: Double) -> Color {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else {
            return self
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let newBrightness = max(0, min(1, brightness + CGFloat(amount)))

        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(newBrightness),
            opacity: Double(alpha)
        )
    }

    /// 获取颜色的对比色（用于文字）
    func contrastingColor() -> Color {
        guard let components = NSColor(self).cgColor.components else {
            return .white
        }

        let r: CGFloat = components.count >= 1 ? components[0] : 0
        let g: CGFloat = components.count >= 2 ? components[1] : 0
        let b: CGFloat = components.count >= 3 ? components[2] : 0

        // 计算亮度
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b

        return luminance > 0.5 ? .black : .white
    }
}
