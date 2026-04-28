import SwiftUI

// MARK: - D04 隧道管理器

/// 端口转发规则管理面板（D04）
/// 规格：640pt 宽，浮动非模态 Panel，快捷键 ⌘⇧U
/// 对齐 Figma-Spec-v2 §11：卡片布局，蓝色新建按钮，副标题
struct TunnelManagerView: View {

    @ObservedObject var tunnelManager: TunnelManager

    /// 关闭回调
    var onClose: () -> Void

    // MARK: - 状态

    @State private var selectedRuleID: UUID?
    @State private var showEditPanel: Bool = false
    @State private var editingRule: TunnelRule? = nil

    /// 编辑表单临时副本
    @State private var editDraft: TunnelRule = TunnelRule()
    @State private var showDeleteConfirm = false
    @State private var ruleToDelete: TunnelRule?

    @State private var showStartError: Bool = false
    @State private var startErrorMessage: String = ""

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            actionBarView
            cardListView
            if showEditPanel {
                Divider()
                detailPanelView
            }
        }
        // 对齐规范 §11：sm:max-w-[700px]，bg-white/95 backdrop-blur-2xl，border-[#d2d2d7]/50，rounded-2xl
        .frame(width: 700)
        .frame(minHeight: 300, maxHeight: 560)
        .background {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color.white.opacity(0.95))
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 32, x: 0, y: 16)
        .alert("启动失败", isPresented: $showStartError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(startErrorMessage)
        }
        .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                if let r = ruleToDelete { tunnelManager.removeRule(r) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销。")
        }
    }

    // MARK: - 标题区（含副标题）

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.left.arrow.right")
                .font(DesignTokens.Typography.bodyLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text("隧道管理器")
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("管理 SSH 端口转发与隧道")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .frame(height: 52)
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(Color.white.opacity(0.60))
        }
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - 操作栏（仅新建按钮）

    private var actionBarView: some View {
        HStack {
            Spacer()
            Button(action: { addNewRule() }) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.captionMedium)
                    Text("新建隧道")
                        .font(DesignTokens.Typography.labelSmall)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, DesignTokens.Spacing.micro)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .frame(height: 40)
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(Color.white.opacity(0.60))
        }
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - 卡片列表

    private var cardListView: some View {
        ScrollView {
            if tunnelManager.rules.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(tunnelManager.rules) { rule in
                        TunnelCardView(
                            rule: rule,
                            isSelected: selectedRuleID == rule.id,
                            onToggle: { tunnelManager.toggleTunnel(rule) },
                            onEdit: { selectRule(rule) },
                            onDelete: { confirmDelete(rule) }
                        )
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
        }
        .frame(maxHeight: 300)
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "arrow.left.arrow.right.square")
                .font(DesignTokens.Typography.heroSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .padding(.bottom, DesignTokens.Spacing.xxs)
            Text("暂无隧道规则")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("SSH 隧道可将远端端口映射到本地，或将本地端口转发到远端。")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Button(action: { addNewRule() }) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.labelSmall)
                    Text("新建第一条隧道")
                        .font(DesignTokens.Typography.labelMedium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.xxs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.giant)
    }

    // MARK: - 编辑表单

    @ViewBuilder
    private var detailPanelView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // 详情标题行
            HStack {
                Text("规则详情")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Button("取消") { cancelEdit() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("保存") { saveEdit() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            // 第一行：隧道名称 + 类型
            HStack(spacing: DesignTokens.Spacing.md) {
                FormGroup(label: "隧道名称") {
                    CustomTextField(placeholder: "如：MySQL 数据库", text: $editDraft.name)
                        .font(DesignTokens.Typography.codeSmall)
                }

                FormGroup(label: "转发类型") {
                    Picker("", selection: $editDraft.type) {
                        ForEach(TunnelType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .labelsHidden()
                    .frame(height: 28)
                }
                .frame(width: 160)
            }

            // 第二行：本地地址 + 端口 + 远端目标 + 端口
            HStack(spacing: DesignTokens.Spacing.md) {
                FormGroup(label: "本地地址") {
                    CustomTextField(placeholder: "127.0.0.1", text: $editDraft.localBindAddress)
                        .font(DesignTokens.Typography.codeSmall)
                }
                .frame(width: 140)

                FormGroup(label: "端口") {
                    TextField("8080", value: $editDraft.localPort, format: .number)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.codeSmall)
                        .padding(DesignTokens.Spacing.xs)
                        .background(Color.white.opacity(0.80))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 0.5))
                }
                .frame(width: 72)

                if editDraft.type != .dynamicSocks {
                    FormGroup(label: "远端目标") {
                        CustomTextField(placeholder: "db.internal", text: $editDraft.remoteHost)
                            .font(DesignTokens.Typography.codeSmall)
                    }

                    FormGroup(label: "端口") {
                        TextField("3306", value: $editDraft.remotePort, format: .number)
                            .textFieldStyle(.plain)
                            .font(DesignTokens.Typography.codeSmall)
                            .padding(DesignTokens.Spacing.xs)
                            .background(DesignTokens.Colors.surfaceInput)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5))
                    }
                    .frame(width: 72)
                }
            }

            // 第三行：备注 + 自动启动
            HStack(spacing: DesignTokens.Spacing.md) {
                FormGroup(label: "备注（可选）") {
                    CustomTextField(placeholder: "如：访问生产数据库", text: $editDraft.notes)
                        .font(DesignTokens.Typography.codeSmall)
                }

                Toggle("会话连接时自动启动", isOn: $editDraft.autoStart)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(Color.white.opacity(0.60))
        }
    }

    // MARK: - 辅助视图组件

    private struct FormGroup<Content: View>: View {
        let label: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(label)
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .textCase(.uppercase)
                content
            }
        }
    }

    // MARK: - 操作

    private func addNewRule() {
        let rule = TunnelRule()
        tunnelManager.addRule(rule)
        selectRule(rule)
    }

    private func selectRule(_ rule: TunnelRule) {
        selectedRuleID = rule.id
        editDraft = rule.editableCopy()
        editingRule = rule
        withAnimation(.easeOut(duration: 0.2)) {
            showEditPanel = true
        }
    }

    private func cancelEdit() {
        withAnimation(.easeOut(duration: 0.2)) {
            showEditPanel = false
        }
        editingRule = nil
        selectedRuleID = nil
    }

    private func saveEdit() {
        tunnelManager.applyEdit(from: editDraft)
        cancelEdit()
    }

    private func confirmDelete(_ rule: TunnelRule) {
        ruleToDelete = rule
        showDeleteConfirm = true
    }
}

// MARK: - 隧道卡片视图

private struct TunnelCardView: View {

    @ObservedObject var rule: TunnelRule
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // 第一行：状态点 + 名称 + 操作按钮
            HStack(spacing: DesignTokens.Spacing.sm) {
                Circle()
                    .fill(rule.status.statusColor)
                    .frame(width: 8, height: 8)
                Text(rule.name.isEmpty ? rule.localAddressDisplay : rule.name)
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                Spacer()
                // Start/Stop 按钮
                Button(action: onToggle) {
                    Text(rule.status.isActive ? "停止" : "启动")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(rule.status.isActive ? DesignTokens.Colors.statusConnected : DesignTokens.Colors.textSecondary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.nano)
                        .background(rule.status.isActive ? DesignTokens.Colors.accentSecondary.opacity(0.12) : DesignTokens.Colors.surfaceHover)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                // 编辑按钮
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 26, height: 26)
                        .background(DesignTokens.Colors.surfaceHover)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                // 删除按钮
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
            }
            // 第二行：描述
            Text(rule.descriptionText)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            // 第三行：类型徽章
            TunnelTypeBadgeView(type: rule.type)
        }
        .padding(DesignTokens.Spacing.md)
        .background(isSelected ? DesignTokens.Colors.accentPrimary.opacity(0.08) : Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? DesignTokens.Colors.accentPrimary.opacity(0.30)
                        : Color(hex: "#d2d2d7").opacity(0.50),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
    }
}

// MARK: - 类型标签徽章

private struct TunnelTypeBadgeView: View {
    let type: TunnelType

    var body: some View {
        Text(type.badgeLabel)
            .font(DesignTokens.Typography.captionSmall)
            .foregroundColor(type.badgeColor)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .frame(height: 18)
            .background(type.badgeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMicro, style: .continuous))
    }
}
