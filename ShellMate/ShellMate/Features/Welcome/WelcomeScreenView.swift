import SwiftUI

/// 欢迎界面（首次启动，三步引导）
/// 完全对齐 Figma Make 原型 WelcomeScreen.tsx
struct WelcomeScreenView: View {

    // MARK: - 属性

    var onDismiss: (() -> Void)?
    var onCreateSession: (() -> Void)?
    var onImportConfiguration: (() -> Void)?

    // MARK: - 状态

    @State private var currentStep: Int = 0

    // MARK: - 步骤数据（对齐 Figma welcomeSteps 数组）

    private struct StepData {
        let emoji: String
        let gradientColors: [Color]
        let title: String
        let description: String
    }

    private let steps: [StepData] = [
        StepData(
            emoji: "👋",
            gradientColors: [Color.blue.opacity(0.10), Color.purple.opacity(0.10)],
            title: "Welcome to ShellMate",
            description: "A professional SSH terminal application with macOS design."
        ),
        StepData(
            emoji: "🚀",
            gradientColors: [Color.green.opacity(0.10), Color.blue.opacity(0.10)],
            title: "Powerful Features",
            description: "Multi-tab management, split screen, AI assistant, SFTP."
        ),
        StepData(
            emoji: "⚡",
            gradientColors: [Color.orange.opacity(0.10), Color.red.opacity(0.10)],
            title: "Ready to Get Started?",
            description: "Create your first connection or import configurations."
        )
    ]

    // MARK: - 视图

    var body: some View {
        ZStack {
            // bg-gradient-to-br from-[#f5f5f7] via-white to-[#e8e8ed]
            DesignTokens.Colors.surfaceWindow
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 关闭按钮 — absolute top-4 right-4
                HStack {
                    Spacer()
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.trailing, 16)

                Spacer()

                // 中央内容区（max-w-5xl）
                VStack(spacing: 0) {
                    heroSection
                    Spacer().frame(height: 32)

                    // 步骤 1：特性网格（4格）
                    if currentStep == 1 {
                        featuresGrid
                        Spacer().frame(height: 32)
                    }

                    // 步骤 2：操作卡片（3列）
                    if currentStep == 2 {
                        actionCards
                        Spacer().frame(height: 32)
                    }

                    // 步骤 0 / 1：导航按钮
                    if currentStep < 2 {
                        navigationButtons
                    }
                }
                .frame(maxWidth: 900)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 英雄区

    private var heroSection: some View {
        let step = steps[currentStep]
        return VStack(spacing: 16) {
            // 渐变 emoji 卡片（w-32 h-32 rounded-[2.5rem]）
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(LinearGradient(
                        colors: step.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 128, height: 128)
                    .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 8)
                Text(step.emoji)
                    .font(.system(size: 56))
            }
            .animation(.easeInOut(duration: 0.5), value: currentStep)

            // 标题（text-5xl font-bold text-[#1d1d1f]，48px = text-5xl）
            Text(step.title)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            // 描述（text-xl text-[#86868b]，20px = text-xl）
            Text(step.description)
                .font(.system(size: 20))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            // 步骤指示器
            stepIndicator
        }
    }

    // MARK: - 步骤指示器

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) { currentStep = index }
                }) {
                    if index == currentStep {
                        // w-8 h-2 rounded-full bg-[#007aff]
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.Colors.accentPrimary)
                            .frame(width: 32, height: 8)
                    } else {
                        // w-2 h-2 rounded-full bg-[#d2d2d7]
                        Circle()
                            .fill(DesignTokens.Colors.borderPrimary)
                            .frame(width: 8, height: 8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .padding(.top, 8)
    }

    // MARK: - 步骤 0/1 导航按钮

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // 跳过按钮（variant="ghost"）
            Button(action: { onDismiss?() }) {
                Text("Skip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)

            // 下一步按钮（bg-[#007aff]）
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
            }) {
                HStack(spacing: 6) {
                    Text("Next")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            .buttonStyle(.plain)
            .background(DesignTokens.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 12, x: 0, y: 4)
        }
    }

    // MARK: - 步骤 1 特性展示（grid-cols-4，对齐 Figma WelcomeScreen.tsx currentStep===1）

    private let features: [(emoji: String, label: String)] = [
        ("🔐", "Secure Authentication"),
        ("📁", "SFTP Transfer"),
        ("🤖", "AI Assistant"),
        ("📜", "Script Automation")
    ]

    private var featuresGrid: some View {
        HStack(spacing: 16) {
            ForEach(features, id: \.label) { feature in
                VStack(spacing: 8) {
                    Text(feature.emoji)
                        .font(.system(size: 36))
                    Text(feature.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.lg)
                .background(Color.white.opacity(0.60))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.borderSecondary, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 步骤 2 操作卡片（grid-cols-3，对齐 Figma WelcomeScreen.tsx）

    private var actionCards: some View {
        HStack(spacing: 20) {
            // 创建第一个连接
            actionCard(
                iconName: "plus",
                iconFg: DesignTokens.Colors.accentPrimary,
                iconBg: LinearGradient(
                    colors: [DesignTokens.Colors.accentPrimary.opacity(0.10), DesignTokens.Colors.accentIndigo.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                cardHoverBorder: DesignTokens.Colors.accentPrimary.opacity(0.50),
                title: "Create First Connection",
                description: "Fill in server info to get started",
                buttonTitle: "Create Now",
                buttonFg: .white,
                buttonBg: AnyShapeStyle(DesignTokens.Colors.accentPrimary),
                action: { onCreateSession?() }
            )

            // 导入配置
            actionCard(
                iconName: "arrow.down.doc",
                iconFg: DesignTokens.Colors.statusConnected,
                iconBg: LinearGradient(
                    colors: [DesignTokens.Colors.statusConnected.opacity(0.10), DesignTokens.Colors.statusConnected.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                cardHoverBorder: DesignTokens.Colors.statusConnected.opacity(0.50),
                title: "Import Configuration",
                description: "Import from existing files",
                buttonTitle: "Import",
                buttonFg: DesignTokens.Colors.statusConnected,
                buttonBg: AnyShapeStyle(Color.clear),
                isOutline: true,
                outlineColor: DesignTokens.Colors.statusConnected,
                action: { onImportConfiguration?() }
            )

            // 跳过设置
            actionCard(
                iconName: "sparkles",
                iconFg: DesignTokens.Colors.textSecondary,
                iconBg: LinearGradient(
                    colors: [DesignTokens.Colors.textSecondary.opacity(0.10), DesignTokens.Colors.textTertiary.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                cardHoverBorder: DesignTokens.Colors.textSecondary.opacity(0.50),
                title: "Explore Interface",
                description: "Explore the interface first",
                buttonTitle: "Directly Enter",
                buttonFg: DesignTokens.Colors.textSecondary,
                buttonBg: AnyShapeStyle(Color.black.opacity(0.05)),
                action: { onDismiss?() }
            )
        }
    }

    // MARK: - 操作卡片通用组件

    private func actionCard(
        iconName: String,
        iconFg: Color,
        iconBg: LinearGradient,
        cardHoverBorder: Color,
        title: String,
        description: String,
        buttonTitle: String,
        buttonFg: Color,
        buttonBg: AnyShapeStyle,
        isOutline: Bool = false,
        outlineColor: Color = .clear,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 图标容器（w-14 h-14 = 56pt，rounded-2xl = 16pt）
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 56, height: 56)
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconFg)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // 操作按钮
            Button(action: action) {
                HStack {
                    Spacer()
                    Text(buttonTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(buttonFg)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(buttonFg)
                    Spacer()
                }
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .background(buttonBg)
            .overlay(
                isOutline
                    ? RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(outlineColor, lineWidth: 1)
                    : nil
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        .onTapGesture { action() }
    }
}

// MARK: - 预览

#Preview("欢迎界面 - 步骤 0") {
    WelcomeScreenView(
        onDismiss: { AppLogger.ui.debug("关闭") },
        onCreateSession: { AppLogger.ui.debug("创建会话") },
        onImportConfiguration: { AppLogger.ui.debug("导入配置") }
    )
    .frame(width: 960, height: 720)
}
