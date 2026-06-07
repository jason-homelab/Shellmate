import SwiftUI

// W7 横切层通电：FeedbackCenter.banner(.global) 的渲染宿主
// 与 ToastHost 类似的 ZStack 注入，订阅 activeBanners[.global]
// 在窗口顶部下方滑入，含 InlineRecoveryBanner 完整 Action 按钮组

struct BannerHost: View {

    @ObservedObject private var center = FeedbackCenter.shared

    let slot: FeedbackEvent.BannerSlot

    init(slot: FeedbackEvent.BannerSlot = .global) {
        self.slot = slot
    }

    var body: some View {
        VStack {
            if let event = center.activeBanners[slot] {
                InlineRecoveryBanner(event: event) {
                    center.dismissBanner(slot: slot)
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.sm)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.98))
                ))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(center.activeBanners[slot] != nil)
        .animation(DesignTokens.Animation.spring, value: center.activeBanners[slot]?.id)
    }
}
