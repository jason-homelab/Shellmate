import SwiftUI

// MARK: - D04 隧道管理器

/// 端口转发规则管理面板（D04）
/// 规格：640×480pt，浮动非模态 Panel，快捷键 ⌘⇧U
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
            toolbarView
            tableHeaderView
            tableBodyView
            if showEditPanel, let rule = editingRule {
                Divider()
                detailPanelView(rule: rule)
            }
        }
        .frame(width: 640, height: showEditPanel ? 480 : 292)
        .background(DesignTokens.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DesignTokens.Colors.borderDefault, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.75), radius: 32, x: 0, y: 24)
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

    // MARK: - 子视图

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("隧道管理器")
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        .frame(height: 44)
        .background(DesignTokens.Colors.surfaceOverlay)
        .overlay(Divider(), alignment: .bottom)
    }

    private var toolbarView: some View {
        HStack(spacing: 0) {
            Button(action: { addNewRule() }) {
                Label("新建规则", systemImage: "plus")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            HStack(spacing: 6) {
                Button(action: { tunnelManager.startAll() }) {
                    Label("全部启动", systemImage: "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { tunnelManager.stopAll() }) {
                    Label("全部停止", systemImage: "stop.fill")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(DesignTokens.Colors.surfacePanel)
        .overlay(Divider(), alignment: .bottom)
    }

    private var tableHeaderView: some View {
        HStack(spacing: 0) {
            Text("状态")
                .frame(width: 32)
            Text("类型")
                .frame(width: 72, alignment: .leading)
            Text("本地地址:端口")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("远端目标")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("操作")
                .frame(width: 52)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(DesignTokens.Colors.textDisabled)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(DesignTokens.Colors.surfacePanel)
        .overlay(Divider(), alignment: .bottom)
    }

    private var tableBodyView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if tunnelManager.rules.isEmpty {
                    emptyStateView
                } else {
                    ForEach(tunnelManager.rules) { rule in
                        TunnelRowView(
                            rule: rule,
                            isSelected: selectedRuleID == rule.id,
                            onToggle: { tunnelManager.toggleTunnel(rule) },
                            onDelete: { confirmDelete(rule) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectRule(rule) }
                        Divider().opacity(0.05)
                    }
                }
            }
        }
        .frame(maxHeight: 180)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right.square")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("暂无隧道规则")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private func detailPanelView(rule: TunnelRule) -> some View {
        VStack(spacing: 12) {
            // 详情标题行
            HStack {
                Text("规则详情")
                    .font(.system(size: 11, weight: .medium))
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

            // 第一行：类型 + （暂无绑定会话选择，W11 范围内保持简单）
            HStack(spacing: 12) {
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

                FormGroup(label: "备注（可选）") {
                    TextField("如：访问生产数据库", text: $editDraft.notes)
                        .textFieldStyle(.roundedBorder)
                        .font(DesignTokens.Typography.codeSmall)
                }
            }

            // 第二行：本地地址 + 端口 + 远端目标 + 端口
            HStack(spacing: 12) {
                FormGroup(label: "本地地址") {
                    TextField("127.0.0.1", text: $editDraft.localBindAddress)
                        .textFieldStyle(.roundedBorder)
                        .font(DesignTokens.Typography.codeSmall)
                }
                .frame(width: 140)

                FormGroup(label: "端口") {
                    TextField("8080", value: $editDraft.localPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(DesignTokens.Typography.codeSmall)
                }
                .frame(width: 72)

                if editDraft.type != .dynamicSocks {
                    FormGroup(label: "远端目标") {
                        TextField("db.internal", text: $editDraft.remoteHost)
                            .textFieldStyle(.roundedBorder)
                            .font(DesignTokens.Typography.codeSmall)
                    }

                    FormGroup(label: "端口") {
                        TextField("3306", value: $editDraft.remotePort, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(DesignTokens.Typography.codeSmall)
                    }
                    .frame(width: 72)
                }
            }

            // 第三行：自动启动
            HStack {
                Toggle("会话连接时自动启动", isOn: $editDraft.autoStart)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
            }
        }
        .padding(16)
        .background(DesignTokens.Colors.surfaceWindow)
        .frame(height: 188)
    }

    // MARK: - 辅助视图组件

    private struct FormGroup<Content: View>: View {
        let label: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
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

// MARK: - 隧道行视图

private struct TunnelRowView: View {

    @ObservedObject var rule: TunnelRule
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 状态点
            Circle()
                .fill(rule.status.statusColor)
                .frame(width: 6, height: 6)
                .frame(width: 32)

            // 类型标签
            TunnelTypeBadgeView(type: rule.type)
                .frame(width: 72, alignment: .leading)

            // 本地地址
            Text(rule.localAddressDisplay)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // 远端目标
            Text(rule.remoteAddressDisplay)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // 操作按钮
            HStack(spacing: 2) {
                Button(action: onToggle) {
                    Image(systemName: rule.status.isActive ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(rule.status.isActive
                            ? DesignTokens.Colors.textSecondary
                            : DesignTokens.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
                .frame(width: 20, height: 20)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                }
                .buttonStyle(.plain)
                .frame(width: 20, height: 20)
            }
            .frame(width: 52)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            isSelected
                ? DesignTokens.Colors.accentGlow
                : Color.clear
        )
        .overlay(
            isSelected
                ? Rectangle().frame(width: 2).foregroundColor(DesignTokens.Colors.accentPrimary)
                : nil,
            alignment: .leading
        )
    }
}

// MARK: - 类型标签徽章

private struct TunnelTypeBadgeView: View {
    let type: TunnelType

    var body: some View {
        Text(type.badgeLabel)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundColor(type.badgeColor)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(type.badgeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
