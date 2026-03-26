import SwiftUI

// MARK: - 错误侦探徽章（终端右下角浮层）

/// 当 TerminalController 检测到错误输出时，在终端内容区右下角显示此悬浮徽章。
/// 点击「AI 分析」将错误上下文传入 AI 助手面板。
struct AIErrorDetectiveView: View {

    /// 检测到的错误摘要文本
    let errorText: String

    /// 点击「AI 分析」回调（传入错误文本，供面板预填充）
    var onAnalyze: ((String) -> Void)?

    /// 点击「关闭」回调
    var onDismiss: (() -> Void)?

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.statusConnecting)

            // 错误摘要文本
            Text(errorText)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 200)

            Divider()
                .frame(height: 12)
                .opacity(0.4)

            // AI 分析按钮
            Button {
                onAnalyze?(errorText)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                    Text("AI 分析")
                        .font(DesignTokens.Typography.labelSmall)
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#60A5FA"), Color(hex: "#A78BFA")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            }
            .buttonStyle(.plain)

            // 关闭按钮
            Button { onDismiss?() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(.ultraThinMaterial)
        .overlay(DesignTokens.Colors.glassUltraLight)
        .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                .strokeBorder(
                    DesignTokens.Colors.statusConnecting.opacity(isHovering ? 0.5 : 0.25),
                    lineWidth: 0.75
                )
        )
        .shadow(
            color: DesignTokens.Colors.statusConnecting.opacity(0.12),
            radius: 8, x: 0, y: 2
        )
        .onHover { isHovering = $0 }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - 预览

#Preview("错误侦探徽章") {
    ZStack(alignment: .bottomTrailing) {
        Color.black.opacity(0.9)
        AIErrorDetectiveView(
            errorText: "bash: docker: command not found",
            onAnalyze: { _ in },
            onDismiss: {}
        )
        .padding()
    }
    .frame(width: 600, height: 200)
}
