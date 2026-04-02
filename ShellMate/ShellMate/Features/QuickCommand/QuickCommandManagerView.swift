import SwiftUI

// MARK: - D05 快捷命令管理器

/// 快捷命令管理器面板（D05）
/// 规格：560×460pt，浮动非模态 Panel，快捷键 ⌘⇧K
struct QuickCommandManagerView: View {

    @ObservedObject var store: QuickCommandStore

    /// 执行命令的回调（由 TerminalController 注入）
    var onSendCommand: (QuickCommand) -> Void

    /// 关闭回调
    var onClose: () -> Void

    // MARK: - 状态

    @State private var selectedCommandID: UUID?
    @State private var editingCommand: QuickCommand? = nil
    @State private var showNewSetAlert = false
    @State private var newSetName = ""
    @State private var showDeleteSetConfirm = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            commandSetBar
            contentArea
        }
        // 对齐规范 §12：max-w-[700px]，bg-white/95 backdrop-blur-2xl，border-[#d2d2d7]/50，rounded-2xl
        .frame(width: 560, height: 460)
        .background(Color.white.opacity(0.95))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#d2d2d7").opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 32, x: 0, y: 16)
        .alert("新建命令集", isPresented: $showNewSetAlert) {
            TextField("命令集名称", text: $newSetName)
            Button("创建") {
                if !newSetName.isEmpty {
                    store.addCommandSet(name: newSetName)
                    newSetName = ""
                }
            }
            Button("取消", role: .cancel) { newSetName = "" }
        }
        .confirmationDialog("删除命令集", isPresented: $showDeleteSetConfirm) {
            Button("删除", role: .destructive) {
                if let id = store.selectedSetID { store.deleteCommandSet(id: id) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将删除命令集及其所有命令，且不可撤销。")
        }
    }

    // MARK: - 子视图

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("快捷命令管理器")
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
        .frame(height: 44)
        .background(DesignTokens.Colors.surfaceOverlay)
        .overlay(Divider(), alignment: .bottom)
    }

    private var commandSetBar: some View {
        HStack(spacing: 8) {
            Text("命令集：")
                .font(.system(size: 10.5))
                .foregroundColor(DesignTokens.Colors.textDisabled)

            if store.commandSets.isEmpty {
                Text("无命令集").font(.system(size: 11)).foregroundColor(DesignTokens.Colors.textDisabled)
            } else {
                Picker("", selection: Binding(
                    get: { store.selectedSetID },
                    set: { store.selectedSetID = $0 }
                )) {
                    ForEach(store.commandSets) { set in
                        Text(set.name).tag(Optional(set.id))
                    }
                }
                .labelsHidden()
                .frame(width: 160, height: 26)
            }

            Spacer()

            HStack(spacing: 6) {
                Button("新建命令集") { showNewSetAlert = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button("删除命令集") { showDeleteSetConfirm = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .disabled(store.selectedSetID == nil)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(DesignTokens.Colors.surfacePanel)
        .overlay(Divider(), alignment: .bottom)
    }

    private var contentArea: some View {
        HStack(spacing: 0) {
            commandListPanel
            Divider()
            editPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 左侧命令列表

    private var commandListPanel: some View {
        VStack(spacing: 0) {
            if let set = store.selectedSet {
                commandList(set: set)
            } else {
                emptySetState
            }

            // 底部新建按钮
            Divider()
            Button(action: {
                if let setID = store.selectedSetID {
                    store.addCommand(to: setID, name: "新命令", content: "")
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("新建命令")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .frame(height: 36)
            .background(DesignTokens.Colors.surfacePanel)
            .disabled(store.selectedSetID == nil)
        }
        .frame(width: 180)
        .background(DesignTokens.Colors.surfaceWindow)
    }

    private func commandList(set: QuickCommandSet) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(set.sortedCommands) { cmd in
                    CommandRowView(
                        command: cmd,
                        isSelected: selectedCommandID == cmd.id,
                        onTap: { selectCommand(cmd) },
                        onSend: { onSendCommand(cmd) }
                    )
                    .padding(.vertical, 0)
                }
            }
        }
    }

    private var emptySetState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("选择或新建命令集")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 右侧编辑面板

    @ViewBuilder
    private var editPanel: some View {
        if let cmd = editingCommand {
            QuickCommandEditPanel(
                command: Binding(
                    get: { editingCommand ?? QuickCommand() },
                    set: { editingCommand = $0 }
                ),
                onSave: { saved in
                    if let setID = store.selectedSetID {
                        store.updateCommand(saved, in: setID)
                    }
                    editingCommand = nil
                    selectedCommandID = nil
                },
                onDelete: {
                    if let setID = store.selectedSetID {
                        store.deleteCommand(id: cmd.id, from: setID)
                    }
                    editingCommand = nil
                    selectedCommandID = nil
                }
            )
        } else {
            // 空状态
            VStack(spacing: 10) {
                Image(systemName: "text.cursor")
                    .font(.system(size: 36))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .opacity(0.4)
                Text("选择左侧命令进行编辑")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.surfaceElevated)
        }
    }

    // MARK: - 操作

    private func selectCommand(_ cmd: QuickCommand) {
        selectedCommandID = cmd.id
        editingCommand = cmd
    }
}

// MARK: - 命令行视图

private struct CommandRowView: View {
    let command: QuickCommand
    let isSelected: Bool
    let onTap: () -> Void
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .opacity(0)  // 仅占位（hover 时可动态显示，此处简化）

            Text(command.name.isEmpty ? "（未命名）" : command.name)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(isSelected ? DesignTokens.Colors.accentGlow : Color.clear)
        .overlay(
            isSelected
                ? Rectangle().frame(width: 2).foregroundColor(DesignTokens.Colors.accentPrimary)
                : nil,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - 命令编辑面板

private struct QuickCommandEditPanel: View {

    @Binding var command: QuickCommand
    let onSave: (QuickCommand) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 名称
            VStack(alignment: .leading, spacing: 4) {
                Text("名称")
                    .fieldLabel()
                TextField("查看系统状态", text: $command.name)
                    .textFieldStyle(.roundedBorder)
                    .font(DesignTokens.Typography.bodySmall)
            }

            // 命令内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("命令内容")
                        .fieldLabel()
                    Spacer()
                    Text("支持多行，按序发送")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                }
                TextEditor(text: $command.content)
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(minHeight: 80)
                    .background(DesignTokens.Colors.surfaceWindow)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(DesignTokens.Colors.borderDefault, lineWidth: 1)
                    )
            }

            // 选项
            HStack(spacing: 16) {
                Toggle("末尾自动追加回车", isOn: $command.appendNewline)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .toggleStyle(.checkbox)

                Toggle("逐行发送", isOn: $command.sendLineByLine)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .toggleStyle(.checkbox)

                if command.sendLineByLine {
                    HStack(spacing: 4) {
                        Text("延迟")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textDisabled)
                        TextField("50", value: $command.lineDelay, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .font(DesignTokens.Typography.codeSmall)
                            .frame(width: 44)
                        Text("ms")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textDisabled)
                    }
                }
            }

            Spacer()

            // 底部按钮行
            HStack {
                Button("删除") { onDelete() }
                    .buttonStyle(.borderless)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .font(.system(size: 11))

                Spacer()

                Button("保存") { onSave(command) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(DesignTokens.Colors.surfaceElevated)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 辅助

private extension Text {
    func fieldLabel() -> some View {
        self.font(.system(size: 10, weight: .medium))
            .foregroundColor(DesignTokens.Colors.textTertiary)
            .textCase(.uppercase)
    }
}
