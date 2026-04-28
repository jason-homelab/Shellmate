import SwiftUI

// MARK: - 脚本编辑 Sheet

struct ScriptEditorSheet: View {

    // MARK: - 属性

    var editingScript: Script?
    var onSave: (Script) -> Void
    var onCancel: () -> Void

    // MARK: - 状态

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var category: String = ""
    @State private var content: String = ""
    @State private var isScheduled: Bool = false
    @State private var scheduleDescription: String = ""
    @State private var validationError: String = ""

    private var isEditing: Bool { editingScript != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !category.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerBar

            Divider()

            // 表单
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // 名称
                    FormField(label: "脚本名称", isRequired: true) {
                        CustomTextField(placeholder: "例如：System Health Check", text: $name)
                    }

                    // 描述
                    FormField(label: "描述") {
                        CustomTextField(placeholder: "简短说明脚本用途", text: $description)
                    }

                    // 分类
                    FormField(label: "分类", isRequired: true) {
                        CustomTextField(placeholder: "例如：Monitoring", text: $category)
                    }

                    // 脚本内容
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        HStack {
                            Text("脚本内容")
                                .font(DesignTokens.Typography.labelMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text("*")
                                .foregroundColor(DesignTokens.Colors.statusError)
                                .font(DesignTokens.Typography.labelMedium)
                        }
                        TextEditor(text: $content)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .background(DesignTokens.Colors.surfaceCard)
                            .frame(minHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall)
                                    .stroke(DesignTokens.Colors.borderDefault, lineWidth: 1)
                            )
                    }

                    // 定时执行
                    HStack {
                        Toggle("定时执行", isOn: $isScheduled)
                        if isScheduled {
                            CustomTextField(placeholder: "例如：每天 02:00", text: $scheduleDescription)
                                .frame(maxWidth: 200)
                        }
                    }

                    // 验证错误
                    if !validationError.isEmpty {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(validationError)
                        }
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.statusError)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // 底部按钮
            footerBar
        }
        .frame(width: 600, height: 560)
        .background(DesignTokens.Colors.surfacePanel)
        .onAppear { loadData() }
    }

    // MARK: - 子视图

    private var headerBar: some View {
        HStack {
            Text(isEditing ? "编辑脚本" : "新建脚本")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .glassPanel(radius: 12)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var footerBar: some View {
        HStack {
            Spacer()
            Button("取消", action: onCancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

            Button(isEditing ? "保存" : "创建") {
                saveScript()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canSave)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 逻辑

    private func loadData() {
        guard let s = editingScript else { return }
        name = s.name
        description = s.description
        category = s.category
        content = s.content
        isScheduled = s.isScheduled
        scheduleDescription = s.scheduleDescription
    }

    private func saveScript() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let cat = category.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !cat.isEmpty else {
            validationError = "脚本名称和分类不能为空"
            return
        }

        var script = editingScript ?? Script(name: "", description: "", category: "", content: "")
        script.name = trimmed
        script.description = description.trimmingCharacters(in: .whitespaces)
        script.category = cat
        script.content = content
        script.isScheduled = isScheduled
        script.scheduleDescription = scheduleDescription.trimmingCharacters(in: .whitespaces)
        script.modifiedAt = Date()

        onSave(script)
    }
}

// MARK: - 预览

#Preview("新建脚本") {
    ScriptEditorSheet(
        onSave: { _ in },
        onCancel: {}
    )
}
