import SwiftUI

/// 欢迎界面（首次启动，三步引导）
/// 对齐 Figma-Spec-v2 §13：WelcomeScreen 三步骤、英雄区、操作卡片
struct WelcomeScreenView: View {

    // MARK: - 属性

    var onDismiss: (() -> Void)?
    var onCreateSession: (() -> Void)?

    // MARK: - 状态

    @State private var currentStep: Int = 0

    // MARK: - 步骤数据

    private struct StepData {
        let emoji: String
        let gradientStart: Color
        let gradientEnd: Color
        let title: String
        let description: String
    }

    private let steps: [StepData] = [
        StepData(
            emoji: "👋",
            gradientStart: Color.blue.opacity(0.15),
            gradientEnd: Color.purple.opacity(0.15),
            title: "欢迎使用 ShellMate",
            description: "专为开发者和运维工程师打造的 macOS 原生 SSH 会话管理工具"
        ),
        StepData(
            emoji: "🚀",
            gradientStart: Color.green.opacity(0.15),
            gradientEnd: Color.blue.opacity(0.15),
            title: "强大的功能，极致的体验",
            description: "多标签管理、分屏模式、AI 智能助手、SFTP 文件传输，一切尽在掌控"
        ),
        StepData(
            emoji: "⚡",
            gradientStart: Color.orange.opacity(0.15),
            gradientEnd: Color.red.opacity(0.15),
            title: "准备好了，开始使用！",
            description: "创建您的第一个连接，或导入已有配置，立即开始工作"
        )
    ]

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color(hex: "#f5f5f7"), .white, Color(hex: "#e8e8ed")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.trailing, 16)

                Spacer()

                // 英雄区
                heroSection

                Spacer().frame(height: 32)

                // 步骤指示器
                stepIndicator

                Spacer().frame(height: 40)

                // 步骤内容
                if currentStep < 2 {
                    // 步骤 0 / 1：特性展示 + 导航按钮
                    navigationButtons
                } else {
                    // 步骤 2：操作卡片
                    actionCards
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 英雄区

    private var heroSection: some View {
        let step = steps[currentStep]
        return VStack(spacing: 20) {
            // 渐变图标卡片
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(LinearGradient(
                        colors: [step.gradientStart, step.gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 128, height: 128)
                    .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 8)
                Text(step.emoji)
                    .font(.system(size: 56))
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            // 标题
            Text(step.title)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#1d1d1f"))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            // 描述
            Text(step.description)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#86868b"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
                .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
    }

    // MARK: - 步骤指示器

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                if index == currentStep {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DesignTokens.Colors.accentPrimary)
                        .frame(width: 28, height: 8)
                } else {
                    Circle()
                        .fill(Color(hex: "#d2d2d7"))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .onTapGesture { }
    }

    // MARK: - 步骤 0/1 导航按钮

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            Button("跳过") {
                onDismiss?()
            }
            .buttonStyle(.plain)
            .foregroundColor(Color(hex: "#86868b"))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep += 1
                }
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
            .background(DesignTokens.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - 步骤 2 操作卡片

    private var actionCards: some View {
        HStack(spacing: 20) {
            // 创建第一个连接
            actionCard(
                icon: "plus",
                iconColor: DesignTokens.Colors.accentPrimary,
                iconBgColor: DesignTokens.Colors.accentPrimary.opacity(0.1),
                title: "创建第一个连接",
                description: "填写服务器信息，快速开始工作",
                buttonTitle: "立即创建",
                buttonStyle: .primary
            ) {
                onCreateSession?()
            }

            // 跳过设置
            actionCard(
                icon: "sparkles",
                iconColor: Color(hex: "#86868b"),
                iconBgColor: Color(hex: "#86868b").opacity(0.1),
                title: "探索应用",
                description: "先熟悉界面，稍后再添加连接",
                buttonTitle: "直接进入",
                buttonStyle: .ghost
            ) {
                onDismiss?()
            }
        }
        .frame(maxWidth: 600)
    }

    // MARK: - 操作卡片组件

    private enum ButtonStyleType { case primary, ghost }

    @ViewBuilder
    private func actionCard(
        icon: String,
        iconColor: Color,
        iconBgColor: Color,
        title: String,
        description: String,
        buttonTitle: String,
        buttonStyle: ButtonStyleType,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBgColor)
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#1d1d1f"))

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#86868b"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // 按钮
            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(buttonStyle == .primary ? .white : Color(hex: "#86868b"))
            }
            .buttonStyle(.plain)
            .background(
                buttonStyle == .primary
                    ? DesignTokens.Colors.accentPrimary
                    : Color.black.opacity(0.05)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - 预览

#Preview("欢迎界面 - 步骤 0") {
    WelcomeScreenView(
        onDismiss: { print("关闭") },
        onCreateSession: { print("创建会话") }
    )
    .frame(width: 900, height: 700)
}
