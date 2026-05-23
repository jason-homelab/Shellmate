import SwiftUI

// MARK: - 自动化触发器设置面板（SettingsView 第 6 Tab，技术方案 §3.19）

struct AutomationTriggersSettingsView: View {

    @ObservedObject private var store = AutomationTriggerStore.shared

    @State private var showAddSheet: Bool = false
    @State private var editingTrigger: AutomationTrigger? = nil
    @State private var confirmDelete: AutomationTrigger? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            actionBar

            Rectangle()
                .fill(DesignTokens.Colors.borderPrimary)
                .frame(height: 0.5)

            // 触发器列表
            if store.triggers.isEmpty {
                emptyStateView
            } else {
                triggerList
            }
        }
        .sheet(isPresented: $showAddSheet) {
            TriggerFormSheet(trigger: nil) { newTrigger in
                store.add(newTrigger)
                showAddSheet = false
            }
        }
        .sheet(item: $editingTrigger) { trigger in
            TriggerFormSheet(trigger: trigger) { updated in
                store.update(updated)
                editingTrigger = nil
            }
        }
        .alert("确认删除", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("取消", role: .cancel) { confirmDelete = nil }
            Button("删除", role: .destructive) {
                if let t = confirmDelete { store.delete(t) }
                confirmDelete = nil
            }
        } message: {
            if let t = confirmDelete {
                Text("将删除触发器「\(t.name)」，此操作不可撤销。")
            }
        }
    }

    // MARK: - 操作栏

    private var actionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text("自动化触发器")
                    .font(DesignTokens.Typography.bodySmallStrong)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("终端输出匹配后自动执行预设动作，对标 iTerm2 Triggers")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.captionLarge)
                    Text("添加触发器")
                        .font(DesignTokens.Typography.labelSmall)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "bolt.slash")
                .font(DesignTokens.Typography.displayXLarge)
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("暂无触发器")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("点击「添加触发器」创建一条输出匹配规则")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - 触发器列表

    private var triggerList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(store.triggers) { trigger in
                    triggerRow(trigger)
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }

    // MARK: - 单行

    private func triggerRow(_ trigger: AutomationTrigger) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 启用/禁用切换
            Toggle("", isOn: Binding(
                get: { trigger.isEnabled },
                set: { _ in store.toggle(trigger) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            // 信息列
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(trigger.name)
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(trigger.isEnabled
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textDisabled)
                        .lineLimit(1)

                    Text(trigger.conditionType.rawValue)
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, DesignTokens.Spacing.xxxs)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    // 匹配模式
                    if let pattern = trigger.pattern, !pattern.isEmpty {
                        Text("`\(pattern)`")
                            .font(DesignTokens.Typography.codeSmall)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    Image(systemName: "arrow.right")
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(DesignTokens.Colors.textDisabled)

                    // 动作
                    Text(trigger.actionType.rawValue)
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
            }

            Spacer()

            // 作用域标签
            Text(trigger.scope.displayName)
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())

            // 编辑按钮
            Button {
                editingTrigger = trigger
            } label: {
                Image(systemName: "pencil")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("编辑")

            // 删除按钮
            Button {
                confirmDelete = trigger
            } label: {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
    }
}

// MARK: - 触发器编辑表单

private struct TriggerFormSheet: View {

    let trigger: AutomationTrigger?
    let onSave: (AutomationTrigger) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var scope: AutomationTrigger.TriggerScope
    @State private var conditionType: AutomationTrigger.TriggerConditionType
    @State private var pattern: String
    @State private var caseSensitive: Bool
    @State private var actionType: AutomationTrigger.TriggerActionType
    @State private var actionPayload: String
    @State private var cooldownSeconds: Int
    @State private var regexError: String? = nil

    init(trigger: AutomationTrigger?, onSave: @escaping (AutomationTrigger) -> Void) {
        self.trigger = trigger
        self.onSave = onSave
        _name           = State(initialValue: trigger?.name ?? "")
        _scope          = State(initialValue: trigger?.scope ?? .global)
        _conditionType  = State(initialValue: trigger?.conditionType ?? .outputKeyword)
        _pattern        = State(initialValue: trigger?.pattern ?? "")
        _caseSensitive  = State(initialValue: trigger?.caseSensitive ?? false)
        _actionType     = State(initialValue: trigger?.actionType ?? .notification)
        _actionPayload  = State(initialValue: trigger?.actionPayload ?? "")
        _cooldownSeconds = State(initialValue: trigger?.cooldownSeconds ?? 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(trigger == nil ? "新建触发器" : "编辑触发器")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {

                    // 名称
                    formField("触发器名称") {
                        TextField("如：检测 ERROR 并发通知", text: $name)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.black.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // 作用域
                    formField("作用域") {
                        Picker("", selection: $scope) {
                            Text("全局（所有会话）").tag(AutomationTrigger.TriggerScope.global)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    // 触发条件
                    formField("触发条件") {
                        Picker("", selection: $conditionType) {
                            ForEach(AutomationTrigger.TriggerConditionType.allCases, id: \.self) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    // 匹配模式（仅输出匹配类型）
                    if conditionType.requiresPattern {
                        formField(conditionType == .outputRegex ? "正则表达式" : "关键词") {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField(conditionType == .outputRegex ? "(a+)+" : "error", text: $pattern)
                                    .textFieldStyle(.plain)
                                    .font(DesignTokens.Typography.codeMedium)
                                    .padding(8)
                                    .background(Color.black.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .onChange(of: pattern) { newValue in
                                        if conditionType == .outputRegex {
                                            regexError = AutomationTriggerEngine.validateRegex(newValue)
                                        } else {
                                            regexError = nil
                                        }
                                    }

                                if let err = regexError {
                                    Text("正则语法错误：\(err)")
                                        .font(DesignTokens.Typography.captionLarge)
                                        .foregroundColor(DesignTokens.Colors.statusError)
                                }
                            }
                        }

                        HStack {
                            Text("区分大小写")
                                .font(DesignTokens.Typography.bodyMedium)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Spacer()
                            Toggle("", isOn: $caseSensitive)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .controlSize(.small)
                        }
                    }

                    // 执行动作
                    formField("执行动作") {
                        Picker("", selection: $actionType) {
                            ForEach(AutomationTrigger.TriggerActionType.allCases, id: \.self) { t in
                                #if APPSTORE
                                if t != .runScript {
                                    Text(t.rawValue).tag(t)
                                }
                                #else
                                Text(t.rawValue).tag(t)
                                #endif
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    // 动作载荷
                    if actionType != .highlightLine || true {
                        formField("动作载荷") {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField(actionType.payloadHint, text: $actionPayload)
                                    .textFieldStyle(.plain)
                                    .font(actionType == .sendCommand ? DesignTokens.Typography.codeMedium : DesignTokens.Typography.bodyMedium)
                                    .padding(8)
                                    .background(Color.black.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text("支持变量：{{MATCHED_TEXT}} {{SESSION_NAME}} {{TIMESTAMP}} {{HOST}}")
                                    .font(DesignTokens.Typography.captionSmall)
                                    .foregroundColor(DesignTokens.Colors.textDisabled)
                            }
                        }
                    }

                    // 冷却时间
                    formField("冷却时间（秒）") {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Stepper(value: $cooldownSeconds, in: 0...3600, step: 10) {
                                Text(cooldownSeconds == 0 ? "不限制" : "\(cooldownSeconds) 秒")
                                    .font(DesignTokens.Typography.bodyMedium)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // 底部按钮
            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button(trigger == nil ? "添加" : "保存") {
                    saveTrigger()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || regexError != nil)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 480)
        .background {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(DesignTokens.Colors.surfaceCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
    }

    // MARK: - 辅助

    @ViewBuilder
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(label)
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            content()
        }
    }

    private func saveTrigger() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var result = trigger ?? AutomationTrigger(name: trimmed, scope: scope, conditionType: conditionType, actionType: actionType)
        result.name = trimmed
        result.scope = scope
        result.conditionType = conditionType
        result.pattern = conditionType.requiresPattern && !pattern.isEmpty ? pattern : nil
        result.caseSensitive = caseSensitive
        result.actionType = actionType
        result.actionPayload = actionPayload
        result.cooldownSeconds = cooldownSeconds
        onSave(result)
    }
}
