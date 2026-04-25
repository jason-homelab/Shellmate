import SwiftUI

/// 欢迎界面（首次启动，三步引导）
/// 对齐 Figma-Spec-v2 §13：中文文案 / 6张特性卡片网格 / 第三步竖向行卡片
struct WelcomeScreenView: View {

    // MARK: - ViewModel

    @StateObject private var vm: WelcomeViewModel

    init(
        onDismiss: (() -> Void)? = nil,
        onCreateSession: (() -> Void)? = nil,
        onImportConfiguration: (() -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: WelcomeViewModel(
            onDismiss: onDismiss,
            onCreateSession: onCreateSession,
            onImportConfiguration: onImportConfiguration
        ))
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            DesignTokens.Colors.surfaceWindow.ignoresSafeArea()
            VStack(spacing: 0) {
                closeRow
                Spacer()
                centralContent.frame(maxWidth: 900)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 子区域

    private var closeRow: some View {
        HStack {
            Spacer()
            Button(action: { vm.skip() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(DesignTokens.Colors.surfaceHover)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 16).padding(.trailing, 16)
    }

    private var centralContent: some View {
        VStack(spacing: 0) {
            heroSection
            Spacer().frame(height: 32)
            if vm.currentStep == 1 { featuresGrid; Spacer().frame(height: 32) }
            if vm.currentStep == 2 { actionCards; Spacer().frame(height: 32) }
            if vm.currentStep < 2 {
                navigationButtons
            }
        }
    }

    // MARK: - 英雄区（Figma-Spec-v2 §13 §4.1）

    private var heroSection: some View {
        let step = vm.steps[vm.currentStep]
        return VStack(spacing: 16) {
            ZStack {
                // 步骤 0：背景光晕 + SF Symbol 图标组（Figma-Spec-v2 §13 §4.1）
                if vm.currentStep == 0 {
                    // 背景光晕：accentPrimary.opacity(0.08) 圆形，200pt，blur 40pt
                    Circle()
                        .fill(DesignTokens.Colors.accentPrimary.opacity(0.08))
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)

                    // 左侧装饰：terminal，40pt，textTertiary，向左偏移 60pt
                    Image(systemName: "terminal")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .offset(x: -72, y: 0)

                    // 右侧装饰：lock.shield.fill，40pt，textTertiary，向右偏移 60pt
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .offset(x: 72, y: 0)

                    // 中央图标容器
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(LinearGradient(
                            colors: [
                                DesignTokens.Colors.accentPrimary.opacity(0.15),
                                DesignTokens.Colors.accentIndigo.opacity(0.15)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 128, height: 128)
                        .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.25), radius: 20, x: 0, y: 6)

                    // 中央 SF Symbol：desktopcomputer
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(LinearGradient(
                            colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.50), radius: 12, x: 0, y: 0)
                } else {
                    // 步骤 1/2：保持 emoji 风格
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(LinearGradient(colors: step.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 128, height: 128)
                        .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 8)
                    Text(step.emoji).font(.system(size: 56))
                }
            }
            .frame(width: 200, height: 128)
            .animation(.easeInOut(duration: 0.5), value: vm.currentStep)

            Text(step.title)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: vm.currentStep)
            Text(step.description)
                .font(.system(size: 20))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center).frame(maxWidth: 560)
                .animation(.easeInOut(duration: 0.3), value: vm.currentStep)
            stepIndicator
        }
    }

    // MARK: - 步骤指示器（Figma-Spec-v2 §13 §3）

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<vm.steps.count, id: \.self) { index in
                Button(action: { vm.goToStep(index) }) {
                    if index == vm.currentStep {
                        // 激活：32×8pt，accentPrimary
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.Colors.accentPrimary)
                            .frame(width: 32, height: 8)
                    } else {
                        // 非激活：8×8pt，textTertiary
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.Colors.textTertiary.opacity(0.50))
                            .frame(width: 8, height: 8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.currentStep)
        .padding(.top, 8)
    }

    // MARK: - 步骤 1/2 导航按钮（Figma-Spec-v2 §13 §4.3 / §5.2）

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // 跳过
            Button(action: { vm.skip() }) {
                Text("跳过")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceHover)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)
            // 下一步
            Button(action: { vm.nextStep() }) {
                HStack(spacing: 6) {
                    Text("下一步").font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
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

    // MARK: - 步骤 2 特性网格（四列 Emoji 卡片，对齐 Figma Make grid-cols-4）

    private var featuresGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
            spacing: 16
        ) {
            ForEach(vm.features) { feature in
                VStack(spacing: 12) {
                    Text(feature.icon)
                        .font(.system(size: 36))
                    VStack(spacing: 4) {
                        Text(feature.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        Text(feature.description)
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .padding(16)
                .background(DesignTokens.Colors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.75)
                )
                .shadow(DesignTokens.Shadow.small)
            }
        }
    }

    // MARK: - 步骤 3 三列横向操作卡片（对齐 Figma Make grid-cols-3）

    private var actionCards: some View {
        HStack(spacing: 16) {
            WelcomeActionCard(
                iconName: "plus",
                iconFg: DesignTokens.Colors.accentPrimary,
                gradientColors: [DesignTokens.Colors.accentPrimary.opacity(0.10), DesignTokens.Colors.accentIndigo.opacity(0.10)],
                title: "新建会话",
                description: "填写服务器信息，立即连接远程主机",
                buttonLabel: "新建连接",
                buttonVariant: .primary,
                action: { vm.createSession() }
            )
            WelcomeActionCard(
                iconName: "arrow.down.doc",
                iconFg: DesignTokens.Colors.statusConnected,
                gradientColors: [DesignTokens.Colors.statusConnected.opacity(0.10), DesignTokens.Colors.statusConnected.opacity(0.05)],
                title: "导入配置",
                description: "从 SSH config 文件或其他 SSH 客户端批量导入",
                buttonLabel: "导入配置",
                buttonVariant: .outline,
                action: { vm.importConfiguration() }
            )
            WelcomeActionCard(
                iconName: "sparkles",
                iconFg: DesignTokens.Colors.textSecondary,
                gradientColors: [DesignTokens.Colors.textSecondary.opacity(0.10), DesignTokens.Colors.textSecondary.opacity(0.05)],
                title: "先行探索",
                description: "直接进入主界面，自行探索各项功能",
                buttonLabel: "开始探索",
                buttonVariant: .ghost,
                action: { vm.skip() }
            )
        }
        .frame(maxWidth: 800)
    }
}

// MARK: - WelcomeActionCard（横向三列操作卡片，对齐 Figma Make grid-cols-3）

private struct WelcomeActionCard: View {
    let iconName: String
    let iconFg: Color
    let gradientColors: [Color]
    let title: String
    let description: String
    let buttonLabel: String
    let buttonVariant: ButtonVariant
    let action: () -> Void

    enum ButtonVariant { case primary, outline, ghost }

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 图标容器 44×44
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconFg)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // 操作按钮
            Button(action: action) {
                HStack(spacing: 6) {
                    Text(buttonLabel)
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundColor(buttonVariant == .primary ? .white : iconFg)
                .background {
                    if buttonVariant == .primary {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(DesignTokens.Colors.accentPrimary)
                    } else if buttonVariant == .outline {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(iconFg.opacity(0.50), lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(DesignTokens.Colors.surfaceHover)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .padding(20)
        .background(isHovering ? DesignTokens.Colors.surfaceHover : DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.75)
        )
        .shadow(DesignTokens.Shadow.small)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.hover) { isHovering = hovering }
        }
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

#Preview("欢迎界面 - 步骤 1（特性）") {
    WelcomeScreenView(
        onDismiss: { AppLogger.ui.debug("关闭") },
        onCreateSession: { AppLogger.ui.debug("创建会话") },
        onImportConfiguration: { AppLogger.ui.debug("导入配置") }
    )
    .frame(width: 960, height: 720)
    .onAppear {
        // 预览中直接展示步骤 1
    }
}
