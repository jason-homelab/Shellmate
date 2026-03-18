import SwiftUI

/// 会话外观设置 Tab
/// 包含终端外观相关的配置
struct SessionAppearanceTab: View {

    // MARK: - 属性

    @Binding var colorHex: String
    @Binding var tags: [String]

    // MARK: - 私有状态

    @State private var newTag: String = ""
    @State private var showingColorPicker = false

    // MARK: - 预设颜色

    private let presetColors: [String] = [
        "#4A90D9", // 蓝色
        "#2DCE7A", // 绿色
        "#F0A500", // 黄色
        "#F04060", // 红色
        "#9B59B6", // 紫色
        "#E67E22", // 橙色
        "#1ABC9C", // 青色
        "#34495E"  // 深灰
    ]

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            // 颜色标记
            settingsSection(title: "颜色标记") {
                Text("为会话设置一个颜色，方便在侧边栏中识别")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                HStack(spacing: DesignTokens.Spacing.sm) {
                    // 预设颜色
                    ForEach(presetColors, id: \.self) { hex in
                        colorButton(hex: hex)
                    }

                    // 自定义颜色
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { colorHex = $0.toHex() }
                    ))
                    .labelsHidden()
                    .frame(width: 24, height: 24)
                }
            }

            Divider()

            // 标签管理
            settingsSection(title: "标签") {
                Text("添加标签以便于搜索和分类")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                // 已添加的标签
                if !tags.isEmpty {
                    FlowLayout(spacing: DesignTokens.Spacing.xs) {
                        ForEach(tags, id: \.self) { tag in
                            TagBadgeView(
                                text: tag,
                                isDeletable: true,
                                onDelete: {
                                    withAnimation {
                                        tags.removeAll { $0 == tag }
                                    }
                                }
                            )
                        }
                    }
                }

                // 添加新标签
                HStack {
                    TextField("输入标签名称", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addTag()
                        }

                    Button("添加") {
                        addTag()
                    }
                    .buttonStyle(.bordered)
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 颜色按钮

    @ViewBuilder
    private func colorButton(hex: String) -> some View {
        Button(action: {
            withAnimation(DesignTokens.Animation.fast) {
                colorHex = hex
            }
        }) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(
                            colorHex == hex ? Color.white : Color.clear,
                            lineWidth: 2
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            colorHex == hex ? Color(hex: hex) : Color.clear,
                            lineWidth: 4
                        )
                        .padding(-2)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 设置分组

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.titleSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            content()
        }
    }

    // MARK: - 添加标签

    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmedTag.isEmpty, !tags.contains(trimmedTag) else { return }

        withAnimation {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
}

/// 流式布局（用于标签列表）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            ), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        let containerWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }

        return (
            size: CGSize(width: maxWidth, height: currentY + lineHeight),
            positions: positions
        )
    }
}

// MARK: - 预览

#Preview("外观设置 Tab") {
    SessionAppearanceTab(
        colorHex: .constant("#4A90D9"),
        tags: .constant(["生产", "Linux", "重要"])
    )
    .frame(width: 480, height: 400)
    .background(DesignTokens.Colors.surfacePanel)
}
