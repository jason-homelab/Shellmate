import SwiftUI

// MARK: - WelcomeScreenView
// 1:1 对齐 Figma Make upl5OBUkpLGnOe1u5aQRZ5 WelcomeScreen.tsx

struct WelcomeScreenView: View {

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

    var body: some View {
        ZStack {
            // Figma 21:2: 径向渐变，从顶部中心蓝色放射至底部近白
            // radialGradient centered at top, rgba(7,122,255,0.08)→rgba(245,245,247,1)
            ZStack {
                DesignTokens.Colors.surfaceWindow
                RadialGradient(
                    stops: [
                        .init(color: DesignTokens.Colors.accentPrimary.opacity(0.08), location: 0.0),
                        .init(color: Color(hex: "#4299fd").opacity(0.31), location: 0.25),
                        .init(color: Color(hex: "#7eb7fb").opacity(0.54), location: 0.50),
                        .init(color: Color(hex: "#bad6f9").opacity(0.77), location: 0.75),
                        .init(color: DesignTokens.Colors.surfaceWindow.opacity(0.0),  location: 1.0)
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 800
                )
            }
            .ignoresSafeArea()

            // Close button — absolute top-4 right-4, rounded-full, hover:bg-black/5
            VStack {
                HStack {
                    Spacer()
                    Button(action: { vm.skip() }) {
                        Image(systemName: "xmark")
                            .font(DesignTokens.Typography.labelSmall)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.trailing, DesignTokens.Spacing.lg)
                Spacer()
            }

            // Main content — w-full max-w-5xl, centered
            VStack(spacing: 0) {
                Spacer()
                mainContent
                    .frame(maxWidth: 900)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 主内容

    private var mainContent: some View {
        VStack(spacing: 0) {
            heroSection

            // Step 1: 特性格 grid-cols-4
            if vm.currentStep == 1 {
                featuresGrid
                    .padding(.top, DesignTokens.Spacing.xxl)
            }

            // Step 2: 操作卡 grid-cols-3
            if vm.currentStep == 2 {
                actionCards
                    .padding(.top, DesignTokens.Spacing.xxl)
            }

            // Step 0 & 1: 导航按钮
            if vm.currentStep < 2 {
                navigationButtons
                    .padding(.top, DesignTokens.Spacing.xxl)
            }
        }
    }

    // MARK: - Hero 区（text-center mb-12）

    private var heroSection: some View {
        let step = vm.steps[vm.currentStep]
        return VStack(spacing: DesignTokens.Spacing.lg) {

            // 图标容器：Figma 21:3 140×140 圆形 + 60px emoji
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.08), radius: 30, x: 0, y: 12)

                Text(step.emoji)
                    .font(.system(size: 60))
            }
            .animation(.easeInOut(duration: 0.5), value: vm.currentStep)

            // 标题：Figma 21:5 text-[36px] font-bold
            Text(step.title)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: vm.currentStep)

            // 描述：Figma 21:6 text-[16px] font-normal text-[#8e8e93]
            Text(step.description)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
                .animation(.easeInOut(duration: 0.3), value: vm.currentStep)

            stepIndicator
        }
    }

    // MARK: - 步骤指示器（h-2 rounded-full，active w-8 bg-[#007aff]，inactive w-2 bg-[#d2d2d7]）

    private var stepIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            ForEach(0..<vm.steps.count, id: \.self) { index in
                Button(action: { vm.goToStep(index) }) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(index == vm.currentStep
                              ? DesignTokens.Colors.accentPrimary
                              : DesignTokens.Colors.textDisabled)
                        .frame(width: index == vm.currentStep ? 32 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.currentStep)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, DesignTokens.Spacing.xxs)
    }

    // MARK: - 导航按钮（step 0 & 1）：Figma 21:10-12 蓝色按钮 + 下方跳过文字

    private var navigationButtons: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 下一步：Figma 21:10 bg-[#077aff] h-[48px] w-[140px] rounded-[12px] shadow
            Button(action: { vm.nextStep() }) {
                Text("下一步 →")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 48)
            }
            .buttonStyle(.plain)
            .background(DesignTokens.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.35), radius: 24, x: 0, y: 8)

            // 跳过引导：Figma 21:12 text-[13px] text-[#8e8e93]
            Button(action: { vm.skip() }) {
                Text("跳过引导")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 特性格（step 1）：grid-cols-4 gap-4 mt-8

    private var featuresGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.lg), count: 4),
            spacing: DesignTokens.Spacing.lg
        ) {
            ForEach(vm.features) { feature in
                VStack(spacing: DesignTokens.Spacing.xxs) {
                    // emoji text-4xl
                    Text(feature.icon)
                        .font(.system(size: 36))
                    // label text-sm font-medium
                    Text(feature.label)
                        .font(DesignTokens.Typography.bodyLargeMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.lg)
                // bg-white/60 backdrop-blur-sm rounded-2xl border border-[#d2d2d7]/30
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.60))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.borderSecondary, lineWidth: 0.75)
                )
            }
        }
    }

    // MARK: - 操作卡（step 2）：grid-cols-3 gap-6

    private var actionCards: some View {
        HStack(spacing: DesignTokens.Spacing.xxl) {
            WelcomeActionCard(
                iconName: "plus",
                iconColor: DesignTokens.Colors.accentPrimary,
                gradientColors: [
                    DesignTokens.Colors.accentPrimary.opacity(0.10),
                    DesignTokens.Colors.accentIndigo.opacity(0.10)
                ],
                hoverBorderColor: DesignTokens.Colors.accentPrimary.opacity(0.50),
                title: "新建连接",
                description: "填写服务器信息，立即连接远程主机",
                buttonLabel: "新建连接",
                buttonVariant: .primary,
                action: { vm.createSession() }
            )
            WelcomeActionCard(
                iconName: "arrow.down.doc",
                iconColor: DesignTokens.Colors.statusConnected,
                gradientColors: [
                    DesignTokens.Colors.statusConnected.opacity(0.10),
                    DesignTokens.Colors.statusConnected.opacity(0.05)
                ],
                hoverBorderColor: DesignTokens.Colors.statusConnected.opacity(0.50),
                title: "导入配置",
                description: "从 SSH config 文件或其他 SSH 客户端批量导入",
                buttonLabel: "导入配置",
                buttonVariant: .outline,
                action: { vm.importConfiguration() }
            )
            WelcomeActionCard(
                iconName: "sparkles",
                iconColor: DesignTokens.Colors.textSecondary,
                gradientColors: [
                    DesignTokens.Colors.textSecondary.opacity(0.10),
                    DesignTokens.Colors.textSecondary.opacity(0.05)
                ],
                hoverBorderColor: DesignTokens.Colors.textSecondary.opacity(0.50),
                title: "先行探索",
                description: "直接进入主界面，自行探索各项功能",
                buttonLabel: "开始探索",
                buttonVariant: .ghost,
                action: { vm.skip() }
            )
        }
    }
}

// MARK: - WelcomeActionCard

private struct WelcomeActionCard: View {

    let iconName: String
    let iconColor: Color
    let gradientColors: [Color]
    let hoverBorderColor: Color
    let title: String
    let description: String
    let buttonLabel: String
    let buttonVariant: ButtonVariant
    let action: () -> Void

    enum ButtonVariant { case primary, outline, ghost }

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 图标：w-14 h-14 rounded-2xl, group-hover:scale-110
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                    .fill(LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)

                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .scaleEffect(isHovering ? 1.10 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isHovering)

            // 标题：text-lg text-[#1d1d1f]
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.top, DesignTokens.Spacing.xl)

            // 描述：text-sm text-[#86868b]
            Text(description)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DesignTokens.Spacing.xxs)

            Spacer()

            // 按钮：w-full rounded-xl
            Button(action: action) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Text(buttonLabel)
                        .font(DesignTokens.Typography.labelLarge)
                    Image(systemName: "arrow.right")
                        .font(DesignTokens.Typography.captionLarge)
                        .offset(x: isHovering ? 2 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isHovering)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .foregroundColor(buttonVariant == .primary ? .white : iconColor)
                .background {
                    switch buttonVariant {
                    case .primary:
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                            .fill(DesignTokens.Colors.accentPrimary)
                            .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.20), radius: 20, x: 0, y: 10)
                    case .outline:
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                            .strokeBorder(iconColor.opacity(0.50), lineWidth: 1)
                    case .ghost:
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                            .fill(Color.black.opacity(0.05))
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .padding(DesignTokens.Spacing.xl)
        // bg-white/80 backdrop-blur-xl
        .background(.ultraThinMaterial)
        .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(
                    isHovering ? hoverBorderColor : DesignTokens.Colors.borderPrimary,
                    lineWidth: 0.75
                )
        )
        .shadow(
            color: isHovering ? iconColor.opacity(0.10) : Color.black.opacity(0.04),
            radius: isHovering ? 30 : 10,
            x: 0, y: isHovering ? 15 : 5
        )
        .offset(y: isHovering ? -4 : 0)
        .animation(.easeInOut(duration: 0.3), value: isHovering)
        .onHover { hovering in isHovering = hovering }
    }
}

// MARK: - 预览

#Preview("步骤 0 — 欢迎") {
    WelcomeScreenView(
        onDismiss: {},
        onCreateSession: {},
        onImportConfiguration: {}
    )
    .frame(width: 960, height: 720)
}
