import SwiftUI

// W5 新增：危险粘贴守护（解 UE-P1#18）
// 检测多行粘贴 / 危险命令 / 大量内容（>1000 行），弹出确认覆层

struct PasteGuardOverlay: View {

    let request: PasteGuardRequest?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if let request = request {
            ZStack {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture { onCancel() }

                card(request)
                    .frame(maxWidth: 460)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
            .animation(DesignTokens.Animation.spring, value: request.id)
        }
    }

    @ViewBuilder
    private func card(_ request: PasteGuardRequest) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题行
            HStack(spacing: DesignTokens.Spacing.xs) {
                AppIcon.feedbackWarn.image
                    .font(.system(size: 20))
                    .foregroundColor(DesignTokens.Semantic.feedbackWarnFg)
                Text(request.level.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            }

            // 描述
            Text(request.level.description)
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 危险关键词高亮（若有）
            if !request.flaggedTokens.isEmpty {
                FlaggedTokensView(tokens: request.flaggedTokens)
            }

            // 内容预览（多行 + 等宽体）
            ScrollView {
                Text(request.preview)
                    .font(DesignTokens.Typography.Mono.dataSM)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.xs)
            }
            .frame(maxHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DesignTokens.Colors.surfaceInput)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 1)
                    )
            )

            // 统计
            HStack(spacing: DesignTokens.Spacing.md) {
                statLabel("行数", value: "\(request.lineCount)")
                statLabel("字符", value: "\(request.charCount)")
                Spacer()
            }

            // 操作行
            HStack(spacing: DesignTokens.Spacing.xs) {
                Spacer()
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 80, height: 36)
                        .background(DesignTokens.Colors.glassLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Button(action: onConfirm) {
                    Text(request.level == .danger ? "我已确认，继续粘贴" : "粘贴")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 160, height: 36)
                        .background(
                            request.level == .danger
                                ? DesignTokens.Semantic.feedbackErrorFg
                                : DesignTokens.Colors.accentPrimary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .fill(.regularMaterial)
        )
        .elevation(DesignTokens.Elevation.e4)
    }

    @ViewBuilder
    private func statLabel(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text(value)
                .font(DesignTokens.Typography.Mono.label)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }
}

// MARK: - 危险关键词标签

private struct FlaggedTokensView: View {
    let tokens: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tokens, id: \.self) { token in
                Text(token)
                    .font(DesignTokens.Typography.Mono.label)
                    .foregroundColor(DesignTokens.Semantic.feedbackErrorFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DesignTokens.Semantic.feedbackErrorBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(DesignTokens.Semantic.feedbackErrorBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }
}

// MARK: - 简易 FlowLayout（多行标签换行）

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let maxWidth = proposal.width else {
            return CGSize(width: 0, height: 0)
        }
        var rows: [CGFloat] = [0]
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                totalHeight += rowHeight + spacing
                rows.append(0)
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
