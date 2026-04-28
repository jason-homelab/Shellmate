import SwiftUI

// MARK: - PanelDragHandle
//
// 浮动面板顶部拖拽手柄（居中小胶囊）。
// 用于所有 FloatingPanelWrapper 的顶部，提示用户可拖拽移动面板。

struct PanelDragHandle: View {

    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMicro, style: .continuous)
            .fill(DesignTokens.Colors.borderPrimary)
            .frame(width: 36, height: 5)
            .padding(.top, DesignTokens.Spacing.sm)
            .padding(.bottom, DesignTokens.Spacing.xxs)
    }
}

#Preview {
    PanelDragHandle()
        .padding()
        .background(DesignTokens.Colors.surfacePanel)
}
