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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
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

    // MARK: - 标题行

    // Figma: 左侧图标 + "隧道管理器"，右侧蓝色"+ 新建隧道"按钮，同行
    private var headerRow: some View {
        HStack(spacing: 8) {
            // Figma: 左侧无限符号图标，textTertiary
            Image(systemName: "infinity")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#8e8e93"))

            // Figma: "隧道管理器" 18px semibold #1d1d1f
            Text(verbatim: "隧道管理器")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#1d1d1f"))

            Spacer()

            // Figma: 蓝色"+ 新建隧道"按钮，bg-[#077aff]，h-32，rounded-8，text-13 semibold
            Button(action: { addNewRule() }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text(verbatim: "新建隧道")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color(hex: "#077aff"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color(hex: "#077aff").opacity(0.30), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
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
            Text(verbatim: "名称")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: "类型")
                .frame(width: 88, alignment: .leading)
            Text(verbatim: "本地端口")
                .frame(width: 80, alignment: .leading)
            Text(verbatim: "远程地址")
                .frame(width: 150, alignment: .leading)
            Text(verbatim: "状态")
                .frame(width: 80, alignment: .center)
            // 编辑 + 删除两列占位
            Color.clear.frame(width: 64)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(Color(hex: "#8e8e93"))
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
                    ForEach(Array(tunnelManager.rules.enumerated()), id: \.element.id) { idx, rule in
                        TunnelTableRow(
                            rule: rule,
                            onToggle: { tunnelManager.toggleTunnel(rule) },
                            onEdit: { selectRule(rule) },
                            onDelete: { confirmDelete(rule) }
                        )
                        // Figma: 每行底部 0.5px 分割线（末行不加）
                        if idx < tunnelManager.rules.count - 1 {
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
            Image(systemName: "arrow.left.arrow.right.square")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#d2d2d7"))

            Text("暂无隧道规则")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#8e8e93"))

            Text("SSH 隧道可将远端端口映射到本地，\n或将本地端口转发到远端。")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "#aeaeb2"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
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
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "#aeaeb2"))
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#8e8e93"))
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
                        .background(Color.white)
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
                            .background(Color.white)
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
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#8e8e93"))
            }
        }
        .padding(20)
        .background(Color(hex: "#fafafb"))
    }

    // MARK: - 辅助

    private struct FormGroup<Content: View>: View {
        let label: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#aeaeb2"))
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#1d1d1f"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 类型徽章
            TunnelTypeBadgeView(type: rule.type)
                .frame(width: 88, alignment: .leading)

            // 本地端口（用 String() 避免 LocalizedStringKey 千位格式化）
            Text(String(rule.localPort))
                .font(.system(size: 13, weight: .regular).monospacedDigit())
                .foregroundColor(Color(hex: "#1d1d1f"))
                .frame(width: 80, alignment: .leading)

            // 远程地址
            Text(rule.remoteDisplay)
                .font(.system(size: 12, weight: .regular).monospaced())
                .foregroundColor(Color(hex: "#8e8e93"))
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
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#8e8e93"))
            }
            .buttonStyle(.plain)
            .frame(width: 32, alignment: .center)
            .opacity(isHovering ? 1 : 0)

            // 删除按钮（hover 时加深）
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#aeaeb2"))
            }
            .buttonStyle(.plain)
            .frame(width: 32, alignment: .center)
            .opacity(isHovering ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(isHovering ? Color.black.opacity(0.02) : Color.white)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onEdit() }
    }
}

// MARK: - 类型徽章（Figma：蓝色/橙色 badge）

private struct TunnelTypeBadgeView: View {
    let type: TunnelType

    var body: some View {
        Text(type.badgeLabel)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(type.badgeColor)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(type.badgeColor.opacity(0.12))
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
