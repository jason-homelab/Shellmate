import SwiftUI

// W4 新增：骨架屏组件（解 UE-P1#15）
// shimmer 周期 1400ms、80ms 错峰、左上→右下 30°

// MARK: - Skeleton 色（与 Token 系统并列）

private enum SkeletonColors {
    static let base = Color(nsColor: NSColor(name: nil) { traits in
        traits.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.05)
            : NSColor(srgbRed: 0.91, green: 0.91, blue: 0.93, alpha: 1)
    })

    static let shimmer = Color(nsColor: NSColor(name: nil) { traits in
        traits.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.10)
            : NSColor(srgbRed: 0.95, green: 0.95, blue: 0.97, alpha: 1)
    })
}

// MARK: - Skeleton 行 / 列表

struct SkeletonBar: View {

    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    let delay: Double

    @State private var phase: CGFloat = -1

    init(
        width: CGFloat? = nil,
        height: CGFloat = 12,
        cornerRadius: CGFloat = 4,
        delay: Double = 0
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.delay = delay
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(SkeletonColors.base)
            .overlay(
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, SkeletonColors.shimmer, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: proxy.size.width * 0.4)
                    .offset(x: phase * proxy.size.width * 1.4)
                    .blendMode(.plusLighter)
                }
            )
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.4)
                    .delay(delay)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

struct SkeletonList: View {

    let rowCount: Int
    let style: LoadingPresentation.SkeletonStyle

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<rowCount, id: \.self) { index in
                row(at: index)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var spacing: CGFloat {
        switch style {
        case .sidebarRow:   return DesignTokens.Spacing.xs
        case .fileRow:      return DesignTokens.Spacing.xxs
        case .messageCard:  return DesignTokens.Spacing.md
        case .settingsRow:  return DesignTokens.Spacing.sm
        }
    }

    @ViewBuilder
    private func row(at index: Int) -> some View {
        let delay = Double(index % 5) * 0.08    // 80ms 错峰，5 行循环

        switch style {
        case .sidebarRow:
            HStack(spacing: DesignTokens.Spacing.xs) {
                SkeletonBar(width: 16, height: 16, cornerRadius: 4, delay: delay)
                SkeletonBar(width: nil, height: 12, cornerRadius: 4, delay: delay)
                Spacer(minLength: 0)
                SkeletonBar(width: 8, height: 8, cornerRadius: 4, delay: delay)
            }
            .frame(height: 36)

        case .fileRow:
            HStack(spacing: DesignTokens.Spacing.xs) {
                SkeletonBar(width: 14, height: 14, cornerRadius: 3, delay: delay)
                SkeletonBar(width: 140, height: 11, cornerRadius: 4, delay: delay)
                Spacer(minLength: 8)
                SkeletonBar(width: 50, height: 11, cornerRadius: 4, delay: delay)
                SkeletonBar(width: 80, height: 11, cornerRadius: 4, delay: delay)
            }
            .frame(height: 28)

        case .messageCard:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SkeletonBar(width: 20, height: 20, cornerRadius: 10, delay: delay)
                    SkeletonBar(width: 70, height: 10, cornerRadius: 4, delay: delay)
                }
                SkeletonBar(width: nil, height: 11, cornerRadius: 4, delay: delay)
                SkeletonBar(width: nil, height: 11, cornerRadius: 4, delay: delay + 0.05)
                    .padding(.trailing, 40)
                SkeletonBar(width: nil, height: 11, cornerRadius: 4, delay: delay + 0.10)
                    .padding(.trailing, 80)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SkeletonColors.base.opacity(0.6))
            )

        case .settingsRow:
            HStack(spacing: DesignTokens.Spacing.sm) {
                SkeletonBar(width: 100, height: 12, cornerRadius: 4, delay: delay)
                Spacer(minLength: 0)
                SkeletonBar(width: 180, height: 22, cornerRadius: 6, delay: delay)
            }
            .frame(height: 34)
        }
    }
}

// MARK: - Shimmer 卡片（卡片场景）

struct ShimmerCard: View {

    let layout: LoadingPresentation.ShimmerLayout

    var body: some View {
        switch layout {
        case .card:
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBar(width: 100, height: 14, cornerRadius: 4)
                SkeletonBar(width: nil, height: 11, cornerRadius: 4, delay: 0.08)
                SkeletonBar(width: nil, height: 11, cornerRadius: 4, delay: 0.16)
                    .padding(.trailing, 40)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SkeletonColors.base.opacity(0.6))
            )
        case .banner:
            SkeletonBar(width: nil, height: 56, cornerRadius: 12)
        case .avatar:
            SkeletonBar(width: 40, height: 40, cornerRadius: 20)
        }
    }
}
