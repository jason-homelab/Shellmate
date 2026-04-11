import SwiftUI

// MARK: - O03 同步输入确认弹窗

/// 同步输入模式确认弹窗
/// 规格：400pt 宽，包含已连接会话勾选列表 + 橙色警告横幅
struct SyncInputConfirmView: View {

    // MARK: - 属性

    /// 当前发起同步的 Session ID
    let currentSessionId: UUID

    /// 关闭回调（确认时附带选中的 Session ID 集合）
    var onConfirm: (Set<UUID>) -> Void
    var onCancel: () -> Void

    // MARK: - 状态

    /// 观察 SyncInputStore 以获取实时会话列表
    @ObservedObject private var syncStore = SyncInputStore.shared

    @State private var selectedIds: Set<UUID>

    // MARK: - 初始化

    init(
        currentSessionId: UUID,
        onConfirm: @escaping (Set<UUID>) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.currentSessionId = currentSessionId
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        // 默认勾选当前终端
        self._selectedIds = State(initialValue: [currentSessionId])
    }

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            warningBanner
            sessionList
            actionBar
        }
        .frame(width: 400)
        .background(Color.white.opacity(0.95))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 40, x: 0, y: 20)
    }

    // MARK: - 子视图

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
            }
            Text("启用同步输入模式")
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var warningBanner: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                    .padding(.top, 1)
                Text("同步输入会将你的每次键盘输入广播到所有已选终端，请谨慎操作，避免误操作生产环境。")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(Color(hex: "#b25000"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.10))
            Divider()
        }
    }

    private var sessionList: some View {
        let sessions = syncStore.registeredSessionInfos()
        return VStack(alignment: .leading, spacing: 2) {
            Text("选择参与同步的终端：")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.top, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.xs)

            if sessions.isEmpty {
                Text("暂无其他已注册的终端")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)
            } else {
                ForEach(sessions) { info in
                    sessionRow(info: info)
                }
            }
        }
        .padding(.bottom, DesignTokens.Spacing.md)
    }

    private func sessionRow(info: SyncInputStore.SessionInfo) -> some View {
        let isSelected = selectedIds.contains(info.id)
        let isCurrent  = info.id == currentSessionId

        return HStack(spacing: DesignTokens.Spacing.sm) {
            // 勾选指示器
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected
                        ? DesignTokens.Colors.accentPrimary
                        : Color.black.opacity(0.06))
                    .frame(width: 18, height: 18)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Circle()
                .fill(info.state.stateColor.dotColor)
                .frame(width: 7, height: 7)

            Text(info.title)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            if isCurrent {
                Text("当前")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Colors.accentPrimary.opacity(0.10))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 8)
        .background(isSelected
            ? DesignTokens.Colors.accentPrimary.opacity(0.06)
            : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            // 当前终端默认选中，不允许取消
            if isCurrent { return }
            if selectedIds.contains(info.id) {
                selectedIds.remove(info.id)
            } else {
                selectedIds.insert(info.id)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Spacer()
            Button("取消") { onCancel() }
                .keyboardShortcut(.cancelAction)
            Button("启用同步") {
                onConfirm(selectedIds)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(selectedIds.count < 2)
        }
        .padding(DesignTokens.Spacing.lg)
        .overlay(alignment: .top) { Divider() }
    }
}
