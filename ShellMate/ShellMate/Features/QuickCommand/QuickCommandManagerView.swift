import SwiftUI

// MARK: - D05 快捷命令管理器

/// 快捷命令管理器面板（D05）
/// 对齐 Figma-Spec-v2 §12：单列卡片布局，分类标题，命令卡片（名称/命令文本/执行/编辑/删除）
struct QuickCommandManagerView: View {

    @ObservedObject var store: QuickCommandStore

    /// 执行命令的回调（由 TerminalController 注入）
    var onSendCommand: (QuickCommand) -> Void

    /// 关闭回调
    var onClose: () -> Void

    // MARK: - 状态

    /// 是否展示新建/编辑表单
    @State private var showForm: Bool = false
    /// 正在编辑的命令（nil = 新建）
    @State private var formDraft: QuickCommand = QuickCommand()
    /// 目标命令集 ID
    @State private var formSetID: UUID? = nil
    /// 是否新建（区别于编辑）
    @State private var isNewCommand: Bool = true
    /// 新建命令集弹窗
    @State private var showNewSetAlert: Bool = false
    @State private var newSetName: String = ""
    /// 删除确认
    @State private var pendingDelete: (command: QuickCommand, setID: UUID)? = nil

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            actionBarView
            mainContent
        }
        // Figma 17:2: 660px white card, rounded-2xl, shadow
        .frame(width: 660)
        .frame(minHeight: 360, maxHeight: 560)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
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
        .confirmationDialog("删除命令", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let item = pendingDelete {
                    withAnimation(.easeOut(duration: 0.25)) {
                        store.deleteCommand(id: item.command.id, from: item.setID)
                    }
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("此操作不可撤销。")
        }
    }

    // MARK: - 标题区

    /// 对齐规范 §12 §3：Terminal 图标，标题，描述
    private var headerView: some View {
        HStack(spacing: 8) {
            // Figma 17:3: "⚡  快捷命令" 16px semibold #1d1d1f
            (Text(verbatim: "⚡  ") + Text("快捷命令管理器"))
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            Button(action: onClose) {
                AppIcon.close.image
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
            Rectangle().fill(DesignTokens.Colors.glassBorderTop)
        }
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - 操作栏

    private var actionBarView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 命令集选择器
            if !store.commandSets.isEmpty {
                Picker("", selection: Binding(
                    get: { store.selectedSetID },
                    set: { store.selectedSetID = $0 }
                )) {
                    Text("全部").tag(UUID?.none)
                    ForEach(store.commandSets) { set in
                        Text(set.name).tag(Optional(set.id))
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            Button {
                showNewSetAlert = true
            } label: {
                AppIcon.folderBadgePlus.image
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("新建命令集")

            Spacer()

            // 新建命令按钮（Figma §12：bg-[#077aff]）
            Button {
                formDraft = QuickCommand()
                formSetID = store.selectedSetID ?? store.commandSets.first?.id
                isNewCommand = true
                withAnimation(.easeOut(duration: 0.15)) { showForm = true }
            } label: {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    AppIcon.plus.image
                        .font(DesignTokens.Typography.captionMedium)
                    Text("新建命令")
                        .font(DesignTokens.Typography.labelSmall)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, DesignTokens.Spacing.micro)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.commandSets.isEmpty)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .frame(height: 40)
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(DesignTokens.Colors.glassBorderTop)
        }
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - 主内容区（列表 / 表单）

    @ViewBuilder
    private var mainContent: some View {
        if showForm {
            commandFormView
        } else {
            commandListView
        }
    }

    // MARK: - 命令列表（单列，按命令集分类）

    @ViewBuilder
    private var commandListView: some View {
        if store.commandSets.isEmpty {
            emptySetState
        } else {
            let visibleSets: [QuickCommandSet] = {
                if let id = store.selectedSetID {
                    return store.commandSets.filter { $0.id == id }
                }
                return store.commandSets
            }()

            let hasAnyCommands = visibleSets.contains { !$0.sortedCommands.isEmpty }

            if hasAnyCommands {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        ForEach(visibleSets) { set in
                            if !set.sortedCommands.isEmpty {
                                commandSection(set)
                            }
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                }
            } else {
                emptyCommandsState
            }
        }
    }

    /// 分类区块：标题 + 命令卡片列表
    @ViewBuilder
    private func commandSection(_ set: QuickCommandSet) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Figma §12 §4：text-sm font-semibold text-[#1d1d1f] mb-2 px-1
            Text(set.name)
                .font(DesignTokens.Typography.titleSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.xxxs)
                .padding(.bottom, DesignTokens.Spacing.xxxs)

            ForEach(set.sortedCommands) { cmd in
                commandCard(cmd, setID: set.id)
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
            }
        }
    }

    /// 命令卡片（Figma §12 §5）
    @ViewBuilder
    private func commandCard(_ cmd: QuickCommand, setID: UUID) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // 左侧内容
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.micro) {
                // 命令名（text-sm font-medium text-[#1d1d1f]）
                Text(cmd.name.isEmpty ? "（未命名）" : cmd.name)
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                // 命令文本（Figma 17:2: text-xs font-mono text-[#077aff]）
                if !cmd.content.isEmpty {
                    Text(cmd.content)
                        .font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右侧操作按钮（Figma 17:2）
            HStack(spacing: DesignTokens.Spacing.xxs) {
                // 执行按钮（Figma: bg-[#077aff] h-[28px] rounded-[6px] text-white text-xs）
                Button {
                    onSendCommand(cmd)
                } label: {
                    Text("执行")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(DesignTokens.Colors.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .help("执行命令")

                // 编辑按钮（Figma: bg-[rgba(0,0,0,0.05)] h-[28px] rounded-[6px] text-xs）
                Button {
                    formDraft = cmd
                    formSetID = setID
                    isNewCommand = false
                    withAnimation(.easeOut(duration: 0.15)) { showForm = true }
                } label: {
                    Text("编辑")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .help("编辑命令")

                // 删除按钮（小图标，无背景）
                Button {
                    pendingDelete = (command: cmd, setID: setID)
                } label: {
                    AppIcon.trash.image
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(ScaleButtonStyle())
                .help("删除命令")
            }
        }
        .padding(DesignTokens.Spacing.md)
        // Figma 17:2: bg-white border-[rgba(0,0,0,0.06)] rounded-[10px]
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - 新建/编辑表单

    /// 内联表单（对齐规范 §12 §6）
    private var commandFormView: some View {
        VStack(spacing: 0) {
            // 表单头部
            HStack {
                Text(isNewCommand ? "新建命令" : "编辑命令")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showForm = false }
                } label: {
                    AppIcon.dismiss.image
                        .font(DesignTokens.Typography.titleSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(height: 44)
            .background {
                Rectangle().fill(.thinMaterial)
                Rectangle().fill(DesignTokens.Colors.glassBorderTop)
            }
            .overlay(Divider(), alignment: .bottom)

            // 表单内容
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    // 命令名 *
                    formField(label: "命令名称 *") {
                        TextField("如：System Update", text: $formDraft.name)
                            .textFieldStyle(.plain)
                            .font(DesignTokens.Typography.bodySmall)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(DesignTokens.Colors.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
                            )
                    }

                    // 命令内容 *（Textarea font-mono）
                    formField(label: "命令 *") {
                        ZStack(alignment: .topLeading) {
                            if formDraft.content.isEmpty {
                                Text("sudo apt update && sudo apt upgrade -y")
                                    .font(DesignTokens.Typography.codeTiny)
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 9)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $formDraft.content)
                                .font(DesignTokens.Typography.codeTiny)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                                .frame(minHeight: 72)
                                .scrollContentBackground(.hidden)
                                .background(DesignTokens.Colors.surfaceCard)
                        }
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
                        )
                    }

                    // 目标命令集
                    if !store.commandSets.isEmpty {
                        formField(label: "命令集") {
                            Picker("", selection: $formSetID) {
                                ForEach(store.commandSets) { set in
                                    Text(set.name).tag(Optional(set.id))
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 200)
                        }
                    }

                    // 高级选项
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Toggle(isOn: $formDraft.appendNewline) {
                            Text("末尾自动追加回车")
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.mini)

                        Toggle(isOn: $formDraft.sendLineByLine) {
                            Text("逐行发送")
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    }

                    // Figma §12 §8：底部按钮 flex gap-2 justify-end pt-2
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Spacer()
                        // Cancel（ghost）
                        Button("取消") {
                            withAnimation(.easeOut(duration: 0.15)) { showForm = false }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Colors.surfaceHover)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                        // Add / Update Command（bg-[#077aff]）
                        let canSave = !formDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !formDraft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        Button(isNewCommand ? "添加命令" : "保存") {
                            guard let setID = formSetID else { return }
                            if isNewCommand {
                                store.addCommand(
                                    to: setID,
                                    name: formDraft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                                    content: formDraft.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                            } else {
                                store.updateCommand(formDraft, in: setID)
                            }
                            withAnimation(.easeOut(duration: 0.15)) { showForm = false }
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(canSave
                            ? DesignTokens.Colors.accentPrimary
                            : DesignTokens.Colors.accentPrimary.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .padding(.top, DesignTokens.Spacing.xxs)
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background {
                Rectangle().fill(.thinMaterial)
                Rectangle().fill(DesignTokens.Colors.glassBorderTop)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(label)
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            content()
        }
    }

    // MARK: - 空状态

    private var emptySetState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            AppIcon.terminal.image
                .font(DesignTokens.Typography.heroSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("暂无命令集")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("点击「新建命令集」创建分组，然后添加常用命令")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Button {
                showNewSetAlert = true
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    AppIcon.folderBadgePlus.image
                        .font(DesignTokens.Typography.labelSmall)
                    Text("新建命令集")
                        .font(DesignTokens.Typography.labelMedium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyCommandsState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            AppIcon.textCursor.image
                .font(DesignTokens.Typography.heroSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("暂无快捷命令")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("点击右上角「新建命令」添加第一条命令")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预览

#Preview("快捷命令管理器") {
    let store = QuickCommandStore.shared
    ZStack {
        Color.black.opacity(0.85)
        QuickCommandManagerView(
            store: store,
            onSendCommand: { _ in },
            onClose: {}
        )
        .padding()
    }
    .frame(width: 800, height: 640)
}
