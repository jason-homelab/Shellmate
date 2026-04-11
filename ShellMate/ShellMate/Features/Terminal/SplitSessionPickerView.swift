import SwiftUI

// MARK: - 分屏会话选择弹窗（任务 13.15 升级：支持多选）

/// 选择要在分屏窗格显示的会话
/// - 单选模式：左右/上下分屏，选一个会话即关闭
/// - 多选模式：四格分屏 (2×2)，最多选 3 个额外会话，点击"确认"后关闭
struct SplitSessionPickerView: View {

    // MARK: - 属性

    let sessions: [Session]

    /// 多选模式（四格分屏时为 true）
    var isMultiSelect: Bool = false

    /// 多选上限（四格分屏 = 3，主面板固定为当前标签栈）
    var maxSelection: Int = 3

    /// 单选回调
    var onSelect: ((Session) -> Void)?

    /// 多选确认回调
    var onSelectMultiple: (([Session]) -> Void)?

    /// 取消回调
    var onCancel: (() -> Void)?

    // MARK: - 状态

    @State private var searchText: String = ""
    @State private var selectedIds: Set<Session.ID> = []

    // MARK: - 计算属性

    private var filteredSessions: [Session] {
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedSessions: [Session] {
        selectedIds.compactMap { id in sessions.first { $0.id == id } }
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            searchBar
            sessionList
            Divider()
            footerView
        }
        .background(DesignTokens.Colors.surfacePanel)
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isMultiSelect ? "选择分屏会话（四格）" : "选择分屏会话")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                if isMultiSelect {
                    Text("主面板为当前标签，最多再选 \(maxSelection) 个")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            Spacer()
            Button(action: { onCancel?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            TextField("搜索会话…", text: $searchText)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.bodySmall)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - 会话列表

    @ViewBuilder
    private var sessionList: some View {
        if filteredSessions.isEmpty {
            Spacer()
            Text("没有匹配的会话")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Spacer()
        } else {
            List(filteredSessions, id: \.id) { session in
                if isMultiSelect {
                    multiSelectRow(session)
                } else {
                    singleSelectRow(session)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - 单选行

    private func singleSelectRow(_ session: Session) -> some View {
        Button(action: { onSelect?(session) }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "terminal")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text("\(session.username)@\(session.host):\(session.port)")
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 多选行

    private func multiSelectRow(_ session: Session) -> some View {
        let isSelected = selectedIds.contains(session.id)
        let isDisabled = !isSelected && selectedIds.count >= maxSelection

        return Button(action: { toggleSelection(session) }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 复选框
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected
                            ? DesignTokens.Colors.accentPrimary
                            : DesignTokens.Colors.surfaceWindow)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? DesignTokens.Colors.accentPrimary
                                        : DesignTokens.Colors.borderDefault,
                                    lineWidth: 1.5
                                )
                        )
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // 会话图标
                Image(systemName: "terminal")
                    .font(.system(size: 13))
                    .foregroundColor(isDisabled
                        ? DesignTokens.Colors.textDisabled
                        : DesignTokens.Colors.accentPrimary)
                    .frame(width: 20)

                // 会话信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(isDisabled
                            ? DesignTokens.Colors.textDisabled
                            : DesignTokens.Colors.textPrimary)
                    Text("\(session.username)@\(session.host):\(session.port)")
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }

                Spacer()

                // 选中序号徽章
                if isSelected, let idx = selectedIds.firstIndex(of: session.id) {
                    Text("\(selectedIds.distance(from: selectedIds.startIndex, to: idx) + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(DesignTokens.Colors.accentPrimary)
                        .clipShape(Circle())
                }
            }
            .contentShape(Rectangle())
            .opacity(isDisabled ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - 底部按钮

    @ViewBuilder
    private var footerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if isMultiSelect {
                // 已选数量提示
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(selectedIds.isEmpty
                            ? DesignTokens.Colors.textDisabled
                            : DesignTokens.Colors.statusConnected)
                    Text("已选 \(selectedIds.count) / \(maxSelection)")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()

            Button("取消") { onCancel?() }
                .buttonStyle(.bordered)

            if isMultiSelect {
                Button("确认分屏") {
                    onSelectMultiple?(selectedSessions)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIds.isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - 操作

    private func toggleSelection(_ session: Session) {
        if selectedIds.contains(session.id) {
            selectedIds.remove(session.id)
        } else if selectedIds.count < maxSelection {
            selectedIds.insert(session.id)
        }
    }
}
