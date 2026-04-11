import SwiftUI
import AppKit

// MARK: - S05 颜色设置面板（Figma-Spec-v2 §07 §6）

/// 颜色 Tab：终端背景色、前景色、ANSI 16 色调色板自定义
struct ColorsSettingsView: View {

    // MARK: - 持久化（AppStorage）

    @AppStorage("colors.background")   private var backgroundHex: String = "#1e1e1e"
    @AppStorage("colors.foreground")   private var foregroundHex: String = "#cccccc"
    @AppStorage("colors.ansi")         private var ansiJSON: String = ""

    // MARK: - 本地状态

    /// ANSI 16 色（索引 0-15：8 基础 + 8 高亮）
    @State private var ansiColors: [Color] = ColorsSettingsView.defaultANSI

    // MARK: - 默认 ANSI（ShellMate Dark 主题）

    static let defaultANSI: [Color] = [
        Color(hex: "#1C1C1E"), Color(hex: "#FF453A"), Color(hex: "#4CAF7D"), Color(hex: "#FFD60A"),
        Color(hex: "#0A84FF"), Color(hex: "#BF5AF2"), Color(hex: "#5AC8FA"), Color(hex: "#8E8E9A"),
        Color(hex: "#3A3A3C"), Color(hex: "#FF6961"), Color(hex: "#6FD19B"), Color(hex: "#FFE55C"),
        Color(hex: "#409CFF"), Color(hex: "#DA8FFF"), Color(hex: "#7DD4F8"), Color(hex: "#FFFFFF"),
    ]

    static let ansiNames: [String] = [
        "黑色", "红色", "绿色", "黄色", "蓝色", "洋红", "青色", "白色",
        "亮黑", "亮红", "亮绿", "亮黄", "亮蓝", "亮洋红", "亮青色", "亮白",
    ]

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ① 终端背景色
                settingsSection(title: "终端背景色") {
                    colorRow(
                        label: "Background Color",
                        description: "终端主背景颜色",
                        hex: $backgroundHex
                    )
                }

                Divider().padding(.vertical, 14)

                // ② 前景/文字色
                settingsSection(title: "前景 / 文字色") {
                    colorRow(
                        label: "Foreground Color",
                        description: "终端文字默认颜色",
                        hex: $foregroundHex
                    )
                }

                Divider().padding(.vertical, 14)

                // ③ ANSI 16 色调色板
                settingsSection(title: "高亮颜色（ANSI 16色）") {
                    ansiPaletteGrid
                }

                Divider().padding(.vertical, 14)

                // ④ 重置按钮
                HStack {
                    Spacer()
                    Button(action: resetToDefault) {
                        Text("重置为默认")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .onAppear { loadANSI() }
    }

    // MARK: - 颜色行（bg-white/80 backdrop-blur-sm rounded-xl border）

    private func colorRow(label: String, description: String, hex: Binding<String>) -> some View {
        HStack(spacing: 12) {
            // 色块 + ColorPicker
            ColorPicker("", selection: Binding(
                get: { Color(hex: hex.wrappedValue) },
                set: { newColor in
                    if let ns = NSColor(newColor).usingColorSpace(.sRGB) {
                        hex.wrappedValue = String(
                            format: "#%02X%02X%02X",
                            Int(ns.redComponent * 255),
                            Int(ns.greenComponent * 255),
                            Int(ns.blueComponent * 255)
                        )
                        saveANSI()
                    }
                }
            ))
            .labelsHidden()
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(description)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            // Hex 值展示
            Text(hex.wrappedValue.uppercased())
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(12)
        .background(Color.white.opacity(0.80))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 0.5)
        )
    }

    // MARK: - ANSI 调色板（8×2 网格）

    private var ansiPaletteGrid: some View {
        VStack(spacing: 8) {
            // 基础 8 色
            HStack(spacing: 8) {
                ForEach(0..<8) { i in ansiSwatch(index: i) }
            }
            // 高亮 8 色
            HStack(spacing: 8) {
                ForEach(8..<16) { i in ansiSwatch(index: i) }
            }
        }
    }

    @ViewBuilder
    private func ansiSwatch(index: Int) -> some View {
        let color = Binding<Color>(
            get: { ansiColors.indices.contains(index) ? ansiColors[index] : .gray },
            set: { newColor in
                if ansiColors.indices.contains(index) {
                    ansiColors[index] = newColor
                    saveANSI()
                }
            }
        )

        ColorPicker("", selection: color)
            .labelsHidden()
            .frame(width: 26, height: 26)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
            .help(Self.ansiNames.indices.contains(index) ? Self.ansiNames[index] : "Color \(index)")
    }

    // MARK: - Section 容器

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }

    // MARK: - 持久化

    private func resetToDefault() {
        backgroundHex = "#1e1e1e"
        foregroundHex = "#cccccc"
        ansiColors = Self.defaultANSI
        saveANSI()
    }

    private func loadANSI() {
        guard !ansiJSON.isEmpty,
              let data = ansiJSON.data(using: .utf8),
              let hexList = try? JSONDecoder().decode([String].self, from: data),
              hexList.count == 16
        else { return }
        ansiColors = hexList.map { Color(hex: $0) }
    }

    private func saveANSI() {
        let hexList = ansiColors.compactMap { color -> String? in
            guard let ns = NSColor(color).usingColorSpace(.sRGB) else { return nil }
            return String(
                format: "#%02X%02X%02X",
                Int(ns.redComponent * 255),
                Int(ns.greenComponent * 255),
                Int(ns.blueComponent * 255)
            )
        }
        if let data = try? JSONEncoder().encode(hexList),
           let json = String(data: data, encoding: .utf8) {
            ansiJSON = json
        }
    }
}

// MARK: - 预览

#Preview("颜色设置") {
    ColorsSettingsView()
        .frame(width: 600)
}
