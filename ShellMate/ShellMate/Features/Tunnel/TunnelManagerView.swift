import SwiftUI

// MARK: - D04 隧道管理器
// 1:1 对齐 Figma OBPyCWFtlCx5OEIXwrckZm 节点 16:2

struct TunnelManagerView: View {

    @ObservedObject var tunnelManager: TunnelManager
    var onClose: () -> Void

    // MARK: - 状态

    @State private var showEditPanel: Bool = false
    @State private var editingRule: TunnelRule? = nil
    @State private var editDraft: TunnelRule = TunnelRule()
    @State private var showDeleteConfirm = false
    @State private var ruleToDelete: TunnelRule?
    @State private var showStartError: Bool = false
    @State private var startErrorMessage: String = ""
    @State private var emptyStateAppeared: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // Figma 16:2 标题行：∞ 隧道管理器（左）+ 新建隧道（右）
            headerRow

            // Figma: 列标题行（名称 | 类型 | 本地端口 | 远程地址 | 状态）
            if !tunnelManager.rules.isEmpty {
                columnHeaderRow
            }

            // Figma: 规则列表 or 空态
            ruleListArea

            // 编辑表单（展开时追加在底部）
            if showEditPanel {
                Divider().padding(.horizontal, 20)
                detailPanelView
            }

            // Figma: 页脚统计文字
            footerRow
        }
        // Figma 16:2: 660px white card, rounded-2xl，高度跟随内容（不撑满容器）
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 660)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
        .alert("启动失败", isPresented: $showStartError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(startErrorMessage)
        }
        .confirmationDialog("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                if let r = ruleToDelete {
                    withAnimation(.easeOut(duration: 0.25)) { tunnelManager.removeRule(r) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销。")
        }
    }

    // MARK: - 标题行

    // Figma: 左侧图标 + "隧道管理器"，右侧蓝色"+ 新建隧道"按钮，同行
    private var headerRow: some View {
        HStack(spacing: 8) {
            // Figma 16:3: "⚯  隧道管理器" 16px semibold #1d1d1f，unicode 前缀内联
            (Text(verbatim: "⚯  ") + Text("隧道管理器"))
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // Figma: 蓝色"+ 新建隧道"按钮，bg-[#077aff]，h-32，rounded-8，text-13 semibold
            Button(action: { addNewRule() }) {
                HStack(spacing: 4) {
                    AppIcon.plus.image
                        .font(DesignTokens.Typography.labelSmall)
                    Text("新建隧道")
                        .font(DesignTokens.Typography.bodyMediumStrong)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            // 关闭按钮
            Button(action: onClose) {
                AppIcon.close.image
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSubtle)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        // Figma: 底部 0.5px rgba(0,0,0,0.08) 分割线
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5)
        }
    }

    // MARK: - 列标题行

    // Figma: 名称 | 类型 | 本地端口 | 远程地址 | 状态（灰色 11px semibold 标签）
    private var columnHeaderRow: some View {
        HStack(spacing: 0) {
            Text("名称")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("类型")
                .frame(width: 88, alignment: .leading)
            Text("本地端口")
                .frame(width: 80, alignment: .leading)
            Text("远程地址")
                .frame(width: 150, alignment: .leading)
            Text("状态")
                .frame(width: 80, alignment: .center)
            // 编辑 + 删除两列占位
            Color.clear.frame(width: 64)
        }
        .font(DesignTokens.Typography.labelSmall)
        .foregroundColor(DesignTokens.Colors.textSubtle)
        .padding(.horizontal, 20)
        .frame(height: 32)
        .background(Color.black.opacity(0.02))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5)
        }
    }

    // MARK: - 规则列表区域

    @ViewBuilder
    private var ruleListArea: some View {
        if tunnelManager.rules.isEmpty {
            emptyStateView
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(tunnelManager.rules) { rule in
                        TunnelTableRow(
                            rule: rule,
                            onToggle: { tunnelManager.toggleTunnel(rule) },
                            onEdit: { selectRule(rule) },
                            onDelete: { confirmDelete(rule) }
                        )
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        ))

                        if rule.id != tunnelManager.rules.last?.id {
                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
            // 最多显示 7 行（7×52），超出时内部滚动
            .frame(maxHeight: 364)
        }
    }

    // MARK: - 空态视图

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            AppIcon.arrowLeftRight.image
                .font(DesignTokens.Typography.heroMedium)
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .scaleEffect(emptyStateAppeared ? 1.0 : 0.70)
                .opacity(emptyStateAppeared ? 1.0 : 0.0)
                .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.05), value: emptyStateAppeared)

            Text("暂无隧道规则")
                .font(DesignTokens.Typography.bodyLargeMedium)
                .foregroundColor(DesignTokens.Colors.textSubtle)
                .opacity(emptyStateAppeared ? 1.0 : 0.0)
                .offset(y: emptyStateAppeared ? 0 : 8)
                .animation(.easeOut(duration: 0.35).delay(0.15), value: emptyStateAppeared)

            Text("SSH 隧道可将远端端口映射到本地，\n或将本地端口转发到远端。")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .opacity(emptyStateAppeared ? 1.0 : 0.0)
                .offset(y: emptyStateAppeared ? 0 : 8)
                .animation(.easeOut(duration: 0.35).delay(0.22), value: emptyStateAppeared)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .onAppear { emptyStateAppeared = true }
        .onDisappear { emptyStateAppeared = false }
    }

    // MARK: - 页脚

    // Figma: "共 N 个隧道 · M 个活跃 · K 个已停止"，text-[11px] text-[#aeaeb2]
    private var footerRow: some View {
        let total = tunnelManager.rules.count
        let active = tunnelManager.rules.filter { $0.status.isActive }.count
        let stopped = total - active

        return HStack {
            if total > 0 {
                Text("共 \(total) 个隧道 · \(active) 个活跃 · \(stopped) 个已停止")
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: total)
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 36)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.5)
        }
    }

    // MARK: - 编辑表单

    @ViewBuilder
    private var detailPanelView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("规则详情")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSubtle)
                    .textCase(.uppercase)
                Spacer()
                Button("取消") { cancelEdit() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("保存") { saveEdit() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            HStack(spacing: 12) {
                FormGroup(label: "隧道名称") {
                    CustomTextField(placeholder: "如：MySQL 数据库", text: $editDraft.name)
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

            HStack(spacing: 12) {
                FormGroup(label: "本地地址") {
                    CustomTextField(placeholder: "127.0.0.1", text: $editDraft.localBindAddress)
                }
                .frame(width: 140)

                FormGroup(label: "端口") {
                    TextField("8080", value: $editDraft.localPort,
                              format: IntegerFormatStyle<Int>().grouping(.never))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.12), lineWidth: 1))
                }
                .frame(width: 72)

                if editDraft.type != .dynamicSocks {
                    FormGroup(label: "远端目标") {
                        CustomTextField(placeholder: "db.internal", text: $editDraft.remoteHost)
                    }
                    FormGroup(label: "端口") {
                        TextField("3306", value: $editDraft.remotePort,
                                  format: IntegerFormatStyle<Int>().grouping(.never))
                            .textFieldStyle(.plain)
                            .padding(6)
                            .background(DesignTokens.Colors.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.12), lineWidth: 1))
                    }
                    .frame(width: 72)
                }
            }

            HStack(spacing: 12) {
                FormGroup(label: "备注（可选）") {
                    CustomTextField(placeholder: "如：访问生产数据库", text: $editDraft.notes)
                }
                Toggle("会话连接时自动启动", isOn: $editDraft.autoStart)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSubtle)
            }
        }
        .padding(20)
        .background(DesignTokens.Colors.surfaceWindow)
    }

    // MARK: - 辅助

    private struct FormGroup<Content: View>: View {
        let label: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .textCase(.uppercase)
                content
            }
        }
    }

    private func addNewRule() {
        let rule = TunnelRule()
        tunnelManager.addRule(rule)
        selectRule(rule)
    }

    private func selectRule(_ rule: TunnelRule) {
        editDraft = rule.editableCopy()
        editingRule = rule
        withAnimation(.easeOut(duration: 0.2)) { showEditPanel = true }
    }

    private func cancelEdit() {
        withAnimation(.easeOut(duration: 0.2)) { showEditPanel = false }
        editingRule = nil
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

// MARK: - 表格行视图（对齐 Figma 16:2 行样式）

private struct TunnelTableRow: View {

    @ObservedObject var rule: TunnelRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // 名称列：状态点 + 名称文字
            HStack(spacing: 8) {
                Circle()
                    .fill(rule.status.statusColor)
                    .frame(width: 6, height: 6)
                Text(rule.name.isEmpty ? "（未命名）" : rule.name)
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 类型徽章
            TunnelTypeBadgeView(type: rule.type)
                .frame(width: 88, alignment: .leading)

            // 本地端口（用 String() 避免 LocalizedStringKey 千位格式化）
            Text(String(rule.localPort))
                .font(DesignTokens.Typography.bodyMedium.monospacedDigit())
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 80, alignment: .leading)

            // 远程地址
            Text(rule.remoteDisplay)
                .font(DesignTokens.Typography.bodySmall.monospaced())
                .foregroundColor(DesignTokens.Colors.textSubtle)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            // 状态 Toggle
            Toggle("", isOn: Binding(
                get: { rule.status.isActive },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .frame(width: 80, alignment: .center)

            // 编辑按钮（hover 可见）
            Button(action: onEdit) {
                AppIcon.pencil.image
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSubtle)
            }
            .buttonStyle(.plain)
            .frame(width: 32, alignment: .center)
            .opacity(isHovering ? 1 : 0)

            // 删除按钮（hover 时加深）
            Button(action: onDelete) {
                AppIcon.trash.image
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .frame(width: 32, alignment: .center)
            .opacity(isHovering ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(isHovering ? Color.black.opacity(0.025) : Color.clear)
        .animation(DesignTokens.Animation.hover, value: isHovering)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onEdit() }
        .help(rule.name.isEmpty ? "编辑隧道规则" : "\(rule.name) — 单击编辑")
        .accessibilityLabel(rule.name.isEmpty ? "隧道规则" : rule.name)
        .accessibilityHint("单击编辑，使用开关切换启停")
        .accessibilityAction { onEdit() }
    }
}

// MARK: - 类型徽章（Figma：蓝色/橙色 badge）

private struct TunnelTypeBadgeView: View {
    let type: TunnelType

    var body: some View {
        // Figma 16:15: h-22, rounded-4, bg rgba(7,122,255,0.08), text #077aff 11px medium
        Text(type.badgeLabel)
            .font(DesignTokens.Typography.labelSmall)
            .foregroundColor(type.badgeColor)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(type.badgeColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

// MARK: - TunnelRule 扩展

private extension TunnelRule {
    var remoteDisplay: String {
        if type == .dynamicSocks { return "—" }
        if remoteHost.isEmpty { return "—" }
        return "\(remoteHost):\(remotePort)"
    }
}
