import SwiftUI

// MARK: - 分组表单弹窗

struct GroupFormSheet: View {

    // MARK: - 属性

    var editingGroup: SessionGroup?
    /// 新建子分组时预设的父分组 ID
    var defaultParentId: UUID? = nil
    var onSave: ((SessionGroup) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - 状态

    @State private var name: String = ""
    @State private var colorHex: String = "#4A90D9"

    // MARK: - 预设颜色

    private let presetColors: [String] = [
        "#4A90D9", "#2DCE7A", "#F0A500", "#F04060",
        "#9B59B6", "#E67E22", "#1ABC9C", "#34495E"
    ]

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text(editingGroup != nil ? "编辑分组" : "新建分组")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Button(action: { onCancel?() }) {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // 内容
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                FormField(label: "分组名称", isRequired: true) {
                    CustomTextField(placeholder: "输入分组名称", text: $name)
                }

                FormField(label: "颜色") {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(presetColors, id: \.self) { hex in
                            Button(action: { colorHex = hex }) {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                colorHex == hex ? Color.white : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()

            Divider()

            // 底部按钮
            HStack {
                Spacer()

                Button("取消") {
                    onCancel?()
                }
                .buttonStyle(.bordered)

                Button(editingGroup != nil ? "保存" : "创建") {
                    saveGroup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 400, height: 280)
        .background(DesignTokens.Colors.surfacePanel)
        .onAppear {
            if let group = editingGroup {
                name = group.name
                colorHex = group.colorHex
            }
        }
    }

    private func saveGroup() {
        let group: SessionGroup
        if let existing = editingGroup {
            group = SessionGroup(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                colorHex: colorHex,
                sortOrder: existing.sortOrder,
                isExpanded: existing.isExpanded,
                modifiedAt: Date(),
                parentId: existing.parentId,
                childrenIds: existing.childrenIds
            )
        } else {
            group = SessionGroup(
                name: name.trimmingCharacters(in: .whitespaces),
                colorHex: colorHex,
                parentId: defaultParentId
            )
        }
        onSave?(group)
    }
}
