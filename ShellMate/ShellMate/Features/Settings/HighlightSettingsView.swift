import SwiftUI

/// S01 — 关键词高亮设置面板
/// 管理终端关键字高亮规则：新增、编辑、删除、启用/禁用
struct HighlightSettingsView: View {

    // MARK: - 依赖

    @ObservedObject private var engine = HighlightEngine.shared

    // MARK: - 状态

    /// 是否显示添加规则表单
    @State private var showAddForm: Bool = false

    /// 新规则 - 模式
    @State private var newPattern: String = ""
    /// 新规则 - 使用正则
    @State private var newUseRegex: Bool = false
    /// 新规则 - 大小写敏感
    @State private var newCaseSensitive: Bool = false
    /// 新规则 - 颜色
    @State private var newColor: HighlightColor = .yellow
    /// 是否悬停在某行
    @State private var hoveredRuleId: UUID? = nil

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 全局开关
                globalToggleSection

                Divider()
                    .padding(.vertical, DesignTokens.Spacing.md)

                // 规则集标题行
                ruleSectionHeader

                // 规则表格
                ruleTable

                // 添加规则表单（内联展开）
                if showAddForm {
                    addRuleForm
                        .padding(.top, DesignTokens.Spacing.sm)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
    }

    // MARK: - 全局开关

    private var globalToggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text("启用关键词高亮")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("对终端输出中的关键词注入 ANSI 颜色序列")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            Spacer()
            Toggle("", isOn: $engine.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    // MARK: - 规则集标题行

    private var ruleSectionHeader: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text("规则集")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // 恢复默认
            Button("恢复默认") {
                engine.rules = HighlightRule.defaults
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.small)
            .font(DesignTokens.Typography.captionLarge)

            // 添加规则
            Button(action: { withAnimation { showAddForm.toggle() } }) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: showAddForm ? "minus" : "plus")
                        .font(DesignTokens.Typography.captionMedium)
                    Text("添加规则")
                        .font(DesignTokens.Typography.captionLarge)
                }
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.small)
        }
        .padding(.bottom, 10)
    }

    // MARK: - 规则表格

    private var ruleTable: some View {
        VStack(spacing: 0) {
            // 表头
            HStack(spacing: 0) {
                Text("关键词")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("匹配模式")
                    .frame(width: 72, alignment: .leading)
                Text("颜色")
                    .frame(width: 60, alignment: .leading)
                Text("操作")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(DesignTokens.Typography.captionMedium)
            .foregroundColor(DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(height: 26)
            .background(DesignTokens.Colors.surfacePanel)

            Divider()

            if engine.rules.isEmpty {
                emptyRulesView
            } else {
                ForEach(engine.rules) { rule in
                    ruleRow(rule)
                    if rule.id != engine.rules.last?.id {
                        Divider()
                            .opacity(0.5)
                    }
                }
            }
        }
        .background(DesignTokens.Colors.surfaceWindow)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(DesignTokens.Colors.borderSecondary, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var emptyRulesView: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "highlighter")
                .font(DesignTokens.Typography.displaySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .opacity(0.4)
            Text("尚无高亮规则")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xxl)
    }

    @ViewBuilder
    private func ruleRow(_ rule: HighlightRule) -> some View {
        HStack(spacing: 0) {
            // 启用开关
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { var r = rule; r.enabled = $0; engine.updateRule(r) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
            .frame(width: 32)

            // 关键词
            Text(rule.pattern)
                .font(DesignTokens.Typography.codeTiny)
                .foregroundColor(rule.enabled
                    ? DesignTokens.Colors.textPrimary
                    : DesignTokens.Colors.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, DesignTokens.Spacing.xxs)

            // 匹配模式
            Text(rule.useRegex ? "正则" : "字面量")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 72, alignment: .leading)

            // 颜色预览
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Circle()
                    .fill(rule.color.previewColor)
                    .frame(width: 10, height: 10)
                Text(rule.color.displayName)
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .frame(width: 60, alignment: .leading)

            // 操作按钮（悬停时显示）
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Button(action: { engine.removeRule(id: rule.id) }) {
                    Image(systemName: "trash")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(hoveredRuleId == rule.id
                            ? DesignTokens.Colors.statusError
                            : DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("删除规则")
            }
            .frame(width: 60, alignment: .trailing)
            .opacity(hoveredRuleId == rule.id ? 1 : 0.4)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 38)
        .background(hoveredRuleId == rule.id
            ? DesignTokens.Colors.surfacePanel
            : Color.clear)
        .onHover { hovering in
            hoveredRuleId = hovering ? rule.id : nil
        }
    }

    // MARK: - 添加规则表单

    private var addRuleForm: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 第一行：关键词输入 + 模式选项
            HStack(spacing: 10) {
                CustomTextField(placeholder: "error|ERROR|^Traceback", text: $newPattern)
                    .font(DesignTokens.Typography.codeTiny)
                    .frame(maxWidth: .infinity)

                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Toggle("", isOn: $newUseRegex)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                    Text("正则")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Toggle("", isOn: $newCaseSensitive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                    Text("大小写敏感")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            // 第二行：颜色选择
            HStack(spacing: 10) {
                Text("颜色：")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Picker("", selection: $newColor) {
                    ForEach(HighlightColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(color.previewColor)
                                .frame(width: 10, height: 10)
                            Text(color.displayName)
                        }
                        .tag(color)
                    }
                }
                .labelsHidden()
                .frame(width: 100)

                // 颜色预览
                if !newPattern.isEmpty {
                    Text(newPattern)
                        .font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(newColor.previewColor)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, DesignTokens.Spacing.xxxs)
                        .background(DesignTokens.Colors.surfacePanel)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXXSmall, style: .continuous))
                }

                Spacer()
            }

            // 第三行：操作按钮
            HStack {
                Spacer()

                Button("取消") {
                    withAnimation {
                        showAddForm = false
                        resetForm()
                    }
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)

                Button("添加") {
                    addRule()
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
                .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(DesignTokens.Colors.borderPrimary, lineWidth: 1)
        )
    }

    // MARK: - 操作

    private func addRule() {
        let pattern = newPattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }
        engine.addRule(HighlightRule(
            pattern: pattern,
            color: newColor,
            enabled: true,
            useRegex: newUseRegex
        ))
        withAnimation {
            showAddForm = false
            resetForm()
        }
    }

    private func resetForm() {
        newPattern = ""
        newUseRegex = false
        newCaseSensitive = false
        newColor = .yellow
    }
}

// MARK: - HighlightColor SwiftUI 扩展

extension HighlightColor {
    /// 本地化显示名称（UI 展示，不影响 rawValue 持久化）
    var displayName: LocalizedStringKey {
        switch self {
        case .red:     return "红色"
        case .yellow:  return "黄色"
        case .green:   return "绿色"
        case .cyan:    return "青色"
        case .magenta: return "洋红"
        case .blue:    return "蓝色"
        case .white:   return "白色"
        }
    }

    /// SwiftUI 预览颜色（用于设置面板 UI 展示）
    var previewColor: Color {
        switch self {
        case .red:     return Color(red: 1.0, green: 0.35, blue: 0.35)
        case .yellow:  return Color(red: 1.0, green: 0.85, blue: 0.3)
        case .green:   return Color(red: 0.3, green: 0.9, blue: 0.4)
        case .cyan:    return Color(red: 0.3, green: 0.9, blue: 0.9)
        case .magenta: return Color(red: 0.9, green: 0.4, blue: 0.9)
        case .blue:    return Color(red: 0.35, green: 0.6, blue: 1.0)
        case .white:   return DesignTokens.Colors.surfaceCard
        }
    }
}

// MARK: - 预览

#Preview("关键词高亮设置") {
    HighlightSettingsView()
        .frame(width: 480, height: 520)
        .background(DesignTokens.Colors.surfaceWindow)
}
