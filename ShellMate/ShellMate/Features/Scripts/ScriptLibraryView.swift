import SwiftUI

// MARK: - Script Library 主视图

struct ScriptLibraryView: View {

    // MARK: - 属性

    @StateObject private var store = ScriptStore()

    var onClose: () -> Void

    // MARK: - 状态

    @State private var selectedScriptId: UUID?
    @State private var showEditorSheet: Bool = false
    @State private var editingScript: Script?
    @State private var showDeleteConfirm: Bool = false
    @State private var pendingDeleteId: UUID?
    @State private var executionLogs: [ScriptLogEntry] = []
    @State private var isRunning: Bool = false
    @State private var showScheduleAlert: Bool = false
    @State private var scheduleInput: String = ""
    /// 已折叠的分类名集合
    @State private var collapsedCategories: Set<String> = []

    private var selectedScript: Script? {
        guard let id = selectedScriptId else { return nil }
        return store.scripts.first(where: { $0.id == id })
    }

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 0) {
            // 左侧脚本列表
            sidebarPanel
                .frame(width: 210)

            Rectangle().fill(Color(hex: "#d2d2d7").opacity(0.50)).frame(width: 0.5)

            // 右侧内容区
            if let script = selectedScript {
                detailPanel(script: script)
            } else {
                emptyDetailState
            }
        }
        .frame(width: 1100, height: 680)
        .background {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color.white.opacity(0.90))
        }
        .sheet(isPresented: $showEditorSheet) {
            ScriptEditorSheet(
                editingScript: editingScript,
                onSave: { script in
                    if editingScript != nil {
                        store.updateScript(script)
                    } else {
                        store.addScript(script)
                        selectedScriptId = script.id
                    }
                    showEditorSheet = false
                    editingScript = nil
                },
                onCancel: {
                    showEditorSheet = false
                    editingScript = nil
                }
            )
        }
        .confirmationDialog(
            "删除脚本",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let id = pendingDeleteId {
                    if selectedScriptId == id { selectedScriptId = nil }
                    store.deleteScript(id)
                    pendingDeleteId = nil
                }
            }
            Button("取消", role: .cancel) { pendingDeleteId = nil }
        } message: {
            Text("此操作不可撤销，脚本将被永久删除。")
        }
        .alert("设置定时执行", isPresented: $showScheduleAlert) {
            TextField("例如：每天 02:00", text: $scheduleInput)
            Button("保存") {
                if var s = selectedScript {
                    s.isScheduled = !scheduleInput.isEmpty
                    s.scheduleDescription = scheduleInput
                    store.updateScript(s)
                    scheduleInput = ""
                }
            }
            Button("取消", role: .cancel) { scheduleInput = "" }
        } message: {
            Text("输入执行计划描述（实际定时执行需在服务器配置 crontab）")
        }
    }

    // MARK: - 左侧侧边栏

    private var sidebarPanel: some View {
        VStack(spacing: 0) {
            // 标题头
            sidebarHeader

            Divider()

            // 操作按钮
            VStack(spacing: DesignTokens.Spacing.sm) {
                // New Script
                Button {
                    editingScript = nil
                    showEditorSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(DesignTokens.Typography.bodySmallStrong)
                        Text("New Script")
                            .font(DesignTokens.Typography.labelLarge)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(DesignTokens.Colors.accentPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall))
                }
                .buttonStyle(.plain)

                // Record Session（Video 图标，variant=outline）
                Button {
                    // TODO: 录制会话功能（后续迭代实现）
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "video")
                            .font(DesignTokens.Typography.bodySmallStrong)
                        Text("Record Session")
                            .font(DesignTokens.Typography.labelLarge)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                            .stroke(DesignTokens.Colors.statusError, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .help("录制会话功能即将上线")
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, 10)

            Divider()

            // 脚本列表（可折叠分类）
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(store.groupedScripts, id: \.category) { group in
                        let isCollapsed = collapsedCategories.contains(group.category)
                        Section {
                            if !isCollapsed {
                                ForEach(group.scripts) { script in
                                    scriptRow(script)
                                }
                            }
                        } header: {
                            categoryHeader(group.category, isCollapsed: isCollapsed) {
                                if isCollapsed {
                                    collapsedCategories.remove(group.category)
                                } else {
                                    collapsedCategories.insert(group.category)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(Color.white.opacity(0.60))
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                    .fill(Color.orange)
                    .frame(width: 28, height: 28)
                // FileCode 图标（对齐 Figma-Spec-v2 §14 更新：Code2 → FileCode）
                Image(systemName: "doc.text.fill")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(.white)
            }
            Text("Script Library")
                .font(DesignTokens.Typography.bodyLargeStrong)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(DesignTokens.Colors.surfaceOverlay)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 10)
    }

    private func categoryHeader(_ category: String, isCollapsed: Bool, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack {
                Text(category.uppercased())
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .tracking(0.8)
                Spacer()
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(DesignTokens.Typography.captionSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.xxs)
            .background {
                Rectangle().fill(.thinMaterial)
                Rectangle().fill(Color.white.opacity(0.60))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func scriptRow(_ script: Script) -> some View {
        let isSelected = selectedScriptId == script.id

        return Button {
            selectedScriptId = script.id
            executionLogs = []
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(script.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Text(script.description)
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(isSelected
                        ? .white.opacity(0.8)
                        : DesignTokens.Colors.textSecondary)
                    .lineLimit(2)

                if script.isScheduled {
                    HStack(spacing: DesignTokens.Spacing.nano) {
                        Image(systemName: "clock")
                            .font(DesignTokens.Typography.captionSmall)
                        Text("Scheduled")
                            .font(DesignTokens.Typography.captionMedium)
                    }
                    .foregroundColor(isSelected
                        ? .white.opacity(0.75)
                        : DesignTokens.Colors.textTertiary)
                    .padding(.top, DesignTokens.Spacing.px)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? DesignTokens.Colors.accentPrimary : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 右侧详情面板

    @ViewBuilder
    private func detailPanel(script: Script) -> some View {
        VStack(spacing: 0) {
            // 详情头
            detailHeader(script: script)

            Divider()

            // 操作栏
            actionBar(script: script)

            Divider()

            // 内容区（左：代码 | 右：执行日志）
            HStack(spacing: 0) {
                codePanel(script: script)

                Rectangle().fill(Color(hex: "#d2d2d7").opacity(0.50)).frame(width: 0.5)

                logPanel
            }
        }
    }

    private func detailHeader(script: Script) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(script.name)
                    .font(DesignTokens.Typography.displayXSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(script.description)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                HStack(spacing: DesignTokens.Spacing.sm) {
                    HStack(spacing: DesignTokens.Spacing.micro) {
                        Circle()
                            .fill(DesignTokens.Colors.statusConnected)
                            .frame(width: 7, height: 7)
                        Text(script.category)
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Text("Modified: \(script.modifiedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private func actionBar(script: Script) -> some View {
        HStack(spacing: 10) {
            // Run Script
            Button {
                runScript(script)
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(DesignTokens.Typography.bodySmall)
                    }
                    Text(isRunning ? "Running..." : "Run Script")
                        .font(DesignTokens.Typography.labelLarge)
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(DesignTokens.Colors.statusConnected)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
            .disabled(isRunning)

            // Edit
            Button {
                editingScript = script
                showEditorSheet = true
            } label: {
                HStack(spacing: DesignTokens.Spacing.micro) {
                    Image(systemName: "pencil")
                        .font(DesignTokens.Typography.bodySmall)
                    Text("Edit")
                        .font(DesignTokens.Typography.bodyMedium)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .frame(height: 32)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                        .stroke(DesignTokens.Colors.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Schedule
            Button {
                scheduleInput = script.scheduleDescription
                showScheduleAlert = true
            } label: {
                HStack(spacing: DesignTokens.Spacing.micro) {
                    Image(systemName: "calendar")
                        .font(DesignTokens.Typography.bodySmall)
                    Text("Schedule")
                        .font(DesignTokens.Typography.bodyMedium)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .frame(height: 32)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                        .stroke(DesignTokens.Colors.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Duplicate
            Button {
                store.duplicateScript(script)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(DesignTokens.Typography.bodyMedium)
                    .frame(width: 32, height: 32)
                    .background(Color(NSColor.controlBackgroundColor))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                            .stroke(DesignTokens.Colors.borderDefault, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("复制脚本")

            // Delete
            Button {
                pendingDeleteId = script.id
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.bodyMedium)
                    .frame(width: 32, height: 32)
                    .background(Color(NSColor.controlBackgroundColor))
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                            .stroke(DesignTokens.Colors.statusError.opacity(0.6), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("删除脚本")

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, 10)
    }

    // MARK: - 代码区

    private func codePanel(script: Script) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 区域标题
            Text("Script Content")
                .font(DesignTokens.Typography.bodySmallStrong)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, 10)

            Rectangle().fill(Color(hex: "#d2d2d7").opacity(0.50)).frame(height: 0.5)

            // 代码内容（只读）
            ScrollView([.vertical, .horizontal]) {
                Text(script.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.lg)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white.opacity(0.80))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 执行日志区

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            Text("Execution Log")
                .font(DesignTokens.Typography.bodySmallStrong)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, 10)

            Rectangle().fill(Color(hex: "#d2d2d7").opacity(0.50)).frame(height: 0.5)

            if executionLogs.isEmpty {
                // 空状态
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text(">_")
                        .font(DesignTokens.Typography.displayLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text("No execution logs yet")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text("Run the script to see output")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 日志列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(executionLogs) { entry in
                                logLine(entry)
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                    }
                    .onChange(of: executionLogs.count) { _ in
                        if let last = executionLogs.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color.white.opacity(0.80))
        .frame(maxHeight: .infinity)
        .frame(width: 384)  // w-96 对齐 Figma-Spec-v2 §14 更新
    }

    private func logLine(_ entry: ScriptLogEntry) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                .font(DesignTokens.Typography.codeTiny)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 70, alignment: .trailing)
            Text(entry.output)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(entry.isError ? DesignTokens.Colors.statusError : DesignTokens.Colors.textPrimary)
                .textSelection(.enabled)
        }
        .padding(.vertical, DesignTokens.Spacing.xxxs)
        .id(entry.id)
    }

    // MARK: - 空状态（未选中脚本）

    private var emptyDetailState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(DesignTokens.Typography.heroSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("从左侧选择一个脚本")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 运行脚本

    private func runScript(_ script: Script) {
        guard !isRunning else { return }
        executionLogs = []

        // 将脚本内容通过通知写入当前活跃终端
        AppEvent.postRunScript(content: script.content, name: script.name)

        appendLog(String(format: NSLocalizedString("▶ 已发送：%@", comment: ""), script.name))
        appendLog(NSLocalizedString("脚本内容已写入当前终端会话，执行输出请切换到终端窗口查看。", comment: ""))
        appendLog(NSLocalizedString("提示：若当前无活跃终端连接，请先在侧边栏连接到目标服务器。", comment: ""))
    }

    private func appendLog(_ text: String, isError: Bool = false) {
        executionLogs.append(ScriptLogEntry(output: text, isError: isError))
    }
}

// MARK: - 通知名

extension Notification.Name {
    static let runScriptRequested = Notification.Name("runScriptRequested")
}

// MARK: - 预览

#Preview("Script Library") {
    ScriptLibraryView(onClose: {})
}
