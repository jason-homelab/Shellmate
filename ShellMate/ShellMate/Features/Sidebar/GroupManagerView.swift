import SwiftUI

// MARK: - 分组管理弹窗（任务 13.17）

/// 列出所有已有分组，支持新建、重命名、删除
/// 删除后分组内会话归入"无分组"
/// 对齐 Figma-Spec-v2 §14-§1：400px 宽，blue folder 图标，border-b 行分隔
struct GroupManagerView: View {

    // MARK: - 属性

    @ObservedObject var groupStore: GroupStore
    var onClose: (() -> Void)?

    // MARK: - 状态

    /// 新建分组输入框文字
    @State private var newGroupName: String = ""
    /// 正在编辑（重命名）的分组 ID
    @State private var editingGroupId: UUID? = nil
    /// 编辑中的临时名称
    @State private var editingName: String = ""
    /// 待确认删除的分组
    @State private var pendingDeleteGroup: SessionGroup? = nil
    @FocusState private var newGroupFieldFocused: Bool

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            groupListArea
            Divider()
            newGroupInputArea
        }
        .frame(width: 400)
        .background(DesignTokens.Colors.surfacePanel)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .task {
            await groupStore.loadGroups()
        }
        .alert("确认删除", isPresented: Binding(
            get: { pendingDeleteGroup != nil },
            set: { if !$0 { pendingDeleteGroup = nil } }
        )) {
            Button("取消", role: .cancel) { pendingDeleteGroup = nil }
            Button("删除", role: .destructive) {
                if let group = pendingDeleteGroup {
                    Task { await groupStore.deleteGroup(group) }
                    pendingDeleteGroup = nil
                }
            }
        } message: {
            if let group = pendingDeleteGroup {
                Text("将删除分组「\(group.name)」，该分组下的会话将归入"无分组"。")
            }
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // blue folder 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: "folder.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("分组管理")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("共 \(groupStore.groups.count) 个分组")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 分组列表

    @ViewBuilder
    private var groupListArea: some View {
        if groupStore.isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.xl)
        } else if groupStore.groups.isEmpty {
            Text("暂无分组，在下方新建")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.xl)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(groupStore.groups) { group in
                        groupRow(group)
                        if group.id != groupStore.groups.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }

    // MARK: - 单个分组行

    private func groupRow(_ group: SessionGroup) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 文件夹图标（颜色取分组颜色）
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(group.color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "folder.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(group.color)
            }

            // 分组名（可内联重命名）
            if editingGroupId == group.id {
                TextField("分组名称", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .onSubmit { commitRename(group) }
            } else {
                Text(group.name)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            // 重命名按钮
            if editingGroupId == group.id {
                Button {
                    commitRename(group)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.statusConnected)
                        .frame(width: 28, height: 28)
                        .background(DesignTokens.Colors.statusConnected.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    editingGroupId = nil
                    editingName = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                // 重命名按钮（铅笔）
                Button {
                    editingGroupId = group.id
                    editingName = group.name
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("重命名")

                // 删除按钮（垃圾桶）
                Button {
                    pendingDeleteGroup = group
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.statusError)
                        .frame(width: 28, height: 28)
                        .background(DesignTokens.Colors.statusError.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("删除分组")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 10)
    }

    // MARK: - 新建分组输入区

    private var newGroupInputArea: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.accentPrimary)

            TextField("新建分组名称…", text: $newGroupName)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($newGroupFieldFocused)
                .onSubmit { createGroup() }

            if !newGroupName.isEmpty {
                Button("添加") { createGroup() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - 操作

    private func createGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let group = SessionGroup(name: trimmed)
        Task {
            await groupStore.saveGroup(group)
            await MainActor.run { newGroupName = "" }
        }
    }

    private func commitRename(_ group: SessionGroup) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            editingGroupId = nil
            return
        }
        let updated = SessionGroup(
            id: group.id,
            name: trimmed,
            colorHex: group.colorHex,
            sortOrder: group.sortOrder,
            isExpanded: group.isExpanded,
            modifiedAt: Date(),
            parentId: group.parentId,
            childrenIds: group.childrenIds
        )
        Task {
            await groupStore.saveGroup(updated)
            await MainActor.run { editingGroupId = nil; editingName = "" }
        }
    }
}
