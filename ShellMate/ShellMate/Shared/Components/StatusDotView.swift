import SwiftUI

/// 状态点视图
/// 显示连接状态的圆点，支持脉冲动画和外发光效果
struct StatusDotView: View {

    // MARK: - 属性

    /// 连接状态
    let state: ConnectionState

    /// 尺寸
    var size: CGFloat = DesignTokens.Sizes.statusDotSize

    // MARK: - 私有状态

    @State private var isPulsing: Bool = false

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 外发光效果（已连接状态）
            if state.needsGlow {
                Circle()
                    .fill(state.dotColor.opacity(0.4))
                    .frame(width: size * 2, height: size * 2)
                    .blur(radius: DesignTokens.Sizes.statusDotGlowRadius)
            }

            // 脉冲动画效果（连接中状态）
            if state.needsAnimation {
                Circle()
                    .fill(state.dotColor.opacity(0.3))
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
            }

            // 主圆点
            Circle()
                .fill(state.dotColor)
                .frame(width: size, height: size)
        }
        .frame(width: size * 2.5, height: size * 2.5)
        .onAppear {
            if state.needsAnimation {
                startPulseAnimation()
            }
        }
        .onChange(of: state) { newState in
            if newState.needsAnimation {
                startPulseAnimation()
            } else {
                isPulsing = false
            }
        }
    }

    // MARK: - 私有方法

    /// 启动脉冲动画
    private func startPulseAnimation() {
        withAnimation(
            Animation
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: false)
        ) {
            isPulsing = true
        }
    }
}

// MARK: - 预览

#Preview("状态点 - 所有状态") {
    HStack(spacing: 32) {
        VStack(spacing: 8) {
            StatusDotView(state: .offline)
            Text("离线")
                .font(DesignTokens.Typography.labelSmall)
        }

        VStack(spacing: 8) {
            StatusDotView(state: .connecting)
            Text("连接中")
                .font(DesignTokens.Typography.labelSmall)
        }

        VStack(spacing: 8) {
            StatusDotView(state: .connected)
            Text("已连接")
                .font(DesignTokens.Typography.labelSmall)
        }

        VStack(spacing: 8) {
            StatusDotView(state: .error)
            Text("错误")
                .font(DesignTokens.Typography.labelSmall)
        }
    }
    .padding(DesignTokens.Spacing.xxl)
    .background(DesignTokens.Colors.surfaceWindow)
    .foregroundColor(DesignTokens.Colors.textSecondary)
}

#Preview("状态点 - 尺寸变体") {
    HStack(spacing: 24) {
        StatusDotView(state: .connected, size: 4)
        StatusDotView(state: .connected, size: 6)
        StatusDotView(state: .connected, size: 8)
        StatusDotView(state: .connected, size: 10)
    }
    .padding(DesignTokens.Spacing.xxl)
    .background(DesignTokens.Colors.surfaceWindow)
}
