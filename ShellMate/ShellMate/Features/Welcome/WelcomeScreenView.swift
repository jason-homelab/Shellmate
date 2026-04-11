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
            title: "欢迎使用 ShellMate",
            description: "专为开发者和运维工程师打造的 macOS 原生 SSH 会话管理工具"
        ),
        StepData(
            emoji: "🚀",
            gradientColors: [Color.green.opacity(0.10), Color.blue.opacity(0.10)],
            title: "强大的功能，极致的体验",
            description: "多标签管理、分屏模式、AI 智能助手、SFTP 文件传输，一切尽在掌控"
        ),
        StepData(
            emoji: "⚡",
            gradientColors: [Color.orange.opacity(0.10), Color.red.opacity(0.10)],
            title: "准备好了，开始使用！",
            description: "创建您的第一个连接，或导入已有配置，立即开始工作"
        )
    ]

    // MARK: - 视图

    var body: some View {
        ZStack {
            // bg-gradient-to-br from-[#f5f5f7] via-white to-[#e8e8ed]
            LinearGradient(
                colors: [Color(hex: "#f5f5f7"), .white, Color(hex: "#e8e8ed")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 关闭按钮 — absolute top-4 right-4
                HStack {
                    Spacer()
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#1d1d1f"))
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
                .foregroundColor(Color(hex: "#1d1d1f"))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            // 描述（text-xl text-[#86868b]，20px = text-xl）
            Text(step.description)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#86868b"))
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
                            .fill(Color(hex: "#007aff"))
                            .frame(width: 32, height: 8)
                    } else {
                        // w-2 h-2 rounded-full bg-[#d2d2d7]
                        Circle()
                            .fill(Color(hex: "#d2d2d7"))
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
                Text("跳过")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#86868b"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            // 下一步按钮（bg-[#007aff]）
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) { currentStep += 1 }
            }) {
                HStack(spacing: 6) {
                    Text("下一步")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(Color(hex: "#007aff"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color(hex: "#007aff").opacity(0.30), radius: 12, x: 0, y: 4)
        }
    }

    // MARK: - 步骤 1 特性展示（grid-cols-4，对齐 Figma WelcomeScreen.tsx currentStep===1）

    private let features: [(emoji: String, label: String)] = [
        ("🔐", "安全加密"),
        ("📁", "SFTP 传输"),
        ("🤖", "AI 助手"),
        ("📜", "脚本自动化")
    ]

    private var featuresGrid: some View {
        HStack(spacing: 16) {
            ForEach(features, id: \.label) { feature in
                VStack(spacing: 8) {
                    Text(feature.emoji)
                        .font(.system(size: 36))
                    Text(feature.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#1d1d1f"))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.white.opacity(0.60))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(hex: "#d2d2d7").opacity(0.30), lineWidth: 1)
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
                iconFg: Color(hex: "#007aff"),
                iconBg: LinearGradient(
                    colors: [Color(hex: "#007aff").opacity(0.10), Color(hex: "#5856d6").opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                cardHoverBorder: Color(hex: "#007aff").opacity(0.50),
                title: "创建第一个连接",
                description: "填写服务器信息，快速开始工作",
                buttonTitle: "立即创建",
                buttonFg: .white,
                buttonBg: AnyShapeStyle(Color(hex: "#007aff")),
                action: { onCreateSession?() }
            )

            // 导入配置
            actionCard(
                iconName: "arrow.down.doc",
                iconFg: Color(hex: "#34c759"),
                iconBg: LinearGradient(
                    colors: [Color(hex: "#34c759").opacity(0.10), Color(hex: "#30d158").opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                cardHoverBorder: Color(hex: "#34c759").opacity(0.50),
                title: "导入配置",
                description: "从文件导入已有的会话配置",
                buttonTitle: "导入配置",
                buttonFg: Color(hex: "#34c759"),
                buttonBg: AnyShapeStyle(Color.clear),
                isOutline: true,
                outlineColor: Color(hex: "#34c759"),
                action: { onImportConfiguration?() }
            )

            // 跳过设置
            actionCard(
                iconName: "sparkles",
                iconFg: Color(hex: "#86868b"),
                iconBg: LinearGradient(
                    colors: [Color(hex: "#86868b").opacity(0.10), Color(hex: "#636366").opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                cardHoverBorder: Color(hex: "#86868b").opacity(0.50),
                title: "探索应用",
                description: "先熟悉界面，稍后再添加连接",
                buttonTitle: "直接进入",
                buttonFg: Color(hex: "#86868b"),
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
                    .foregroundColor(Color(hex: "#1d1d1f"))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#86868b"))
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
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 1)
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
