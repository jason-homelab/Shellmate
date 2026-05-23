// UI 重构 by Frontend Designer Style
import SwiftUI

/// 空状态视图 — Void 设计语言 v2
/// 统一空状态：渐变图标容器 + 精致排版 + GlassButton 操作按钮
struct EmptyStateView: View {

    // MARK: - 属性

    var iconName: String? = nil
    var iconColor: Color? = nil      // 图标主色，nil 时用 teal/indigo 渐变
    let title: LocalizedStringKey
    var description: LocalizedStringKey?
    var buttonTitle: LocalizedStringKey?
    var onButtonTap: (() -> Void)?

    // MARK: - 入场动画状态

    @State private var appeared = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            if let iconName {
                iconContainer(iconName)
                    .scaleEffect(appeared ? 1.0 : 0.75)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.05), value: appeared)
            }

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.labelLargeAlt)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.35).delay(0.15), value: appeared)

                if let description {
                    Text(description)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .opacity(appeared ? 1.0 : 0.0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(.easeOut(duration: 0.35).delay(0.22), value: appeared)
                }
            }

            if let buttonTitle {
                Button(action: { onButtonTap?() }) {
                    Text(buttonTitle)
                        .font(DesignTokens.Typography.labelMedium)
                }
                .buttonStyle(EmptyStateButtonStyle())
                .opacity(appeared ? 1.0 : 0.0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.35).delay(0.30), value: appeared)
            }
        }
        .padding(DesignTokens.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }

    // MARK: - 图标容器

    private func iconContainer(_ iconName: String) -> some View {
        ZStack {
            // 外层漫射光晕
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.accentPrimary.opacity(0.08),
                            DesignTokens.Colors.accentAI.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Colors.accentPrimary.opacity(0.25),
                                    DesignTokens.Colors.accentAI.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                )

            Image(systemName: iconName)
                .font(DesignTokens.Typography.displayLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            iconColor ?? DesignTokens.Colors.accentPrimary,
                            iconColor.map { _ in DesignTokens.Colors.accentPrimary } ?? DesignTokens.Colors.accentAI
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - 空状态专用按钮样式

private struct EmptyStateButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovering ? .white : DesignTokens.Colors.accentPrimary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .fill(
                        isHovering
                            ? DesignTokens.Colors.accentPrimary.opacity(configuration.isPressed ? 0.90 : 1.0)
                            : DesignTokens.Colors.accentPrimary.opacity(0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(
                                DesignTokens.Colors.accentPrimary.opacity(isHovering ? 0 : 0.30),
                                lineWidth: 0.75
                            )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.hover) { isHovering = hovering }
            }
    }
}

// MARK: - 预设样式

extension EmptyStateView {

    /// 无会话空状态
    static func noSessions(onAdd: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            iconName: "desktopcomputer",
            title: "暂无会话",
            description: "添加第一个 SSH 连接，开始管理你的服务器",
            buttonTitle: "+ 新建会话",
            onButtonTap: onAdd
        )
    }

    /// 搜索无结果
    static func noSearchResults(query: String) -> EmptyStateView {
        EmptyStateView(
            iconName: "magnifyingglass",
            title: "未找到结果",
            description: "没有与「\(query)」匹配的会话"
        )
    }

    /// 无分组
    static func noGroups(onAdd: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            iconName: "folder",
            title: "暂无分组",
            description: "创建分组来整理你的会话",
            buttonTitle: "新建分组",
            onButtonTap: onAdd
        )
    }

    /// 加载中
    static var loading: EmptyStateView {
        EmptyStateView(
            iconName: "arrow.triangle.2.circlepath",
            title: "加载中...",
            description: nil
        )
    }

    /// 错误状态
    static func error(message: LocalizedStringKey, onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            iconName: "exclamationmark.triangle",
            iconColor: DesignTokens.Colors.statusError,
            title: "出错了",
            description: message,
            buttonTitle: "重试",
            onButtonTap: onRetry
        )
    }
}

// MARK: - 预览

#Preview("空状态 - 无会话") {
    EmptyStateView.noSessions {}
        .frame(width: 240, height: 400)
        .background(DesignTokens.Colors.surfacePanel)
}

#Preview("空状态 - 搜索无结果") {
    EmptyStateView.noSearchResults(query: "测试服务器")
        .frame(width: 240, height: 300)
        .background(DesignTokens.Colors.surfacePanel)
}

#Preview("空状态 - 错误") {
    EmptyStateView.error(message: "网络连接失败") {}
        .frame(width: 240, height: 300)
        .background(DesignTokens.Colors.surfacePanel)
}
