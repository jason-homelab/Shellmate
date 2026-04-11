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

            Divider()

            // 右侧内容区
            if let script = selectedScript {
                detailPanel(script: script)
            } else {
                emptyDetailState
            }
        }
        .frame(width: 1100, height: 680)
        .background(DesignTokens.Colors.surfaceWindow)
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
            VStack(spacing: 8) {
                // New Script
                Button {
                    editingScript = nil
                    showEditorSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("New Script")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(DesignTokens.Colors.accentPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Record Session
                Button {
                    // TODO: 录制会话功能（后续迭代实现）
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Record Session")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.Colors.statusError, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .help("录制会话功能即将上线")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // 脚本列表
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(store.groupedScripts, id: \.category) { group in
                        Section {
                            ForEach(group.scripts) { script in
                                scriptRow(script)
                            }
                        } header: {
                            categoryHeader(group.category)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var sidebarHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange)
                    .frame(width: 28, height: 28)
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text("Script Library")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(DesignTokens.Colors.surfaceOverlay)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func categoryHeader(_ category: String) -> some View {
        HStack {
            Text(category.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func scriptRow(_ script: Script) -> some View {
        let isSelected = selectedScriptId == script.id

        return Button {
            selectedScriptId = script.id
            executionLogs = []
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(script.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Text(script.description)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected
                        ? .white.opacity(0.8)
                        : DesignTokens.Colors.textSecondary)
                    .lineLimit(2)

                if script.isScheduled {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("Scheduled")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(isSelected
                        ? .white.opacity(0.75)
                        : DesignTokens.Colors.textTertiary)
                    .padding(.top, 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

                Divider()

                logPanel
            }
        }
    }

    private func detailHeader(script: Script) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(script.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(script.description)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(DesignTokens.Colors.statusConnected)
                            .frame(width: 7, height: 7)
                        Text(script.category)
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Text("Modified: \(script.modifiedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func actionBar(script: Script) -> some View {
        HStack(spacing: 10) {
            // Run Script
            Button {
                runScript(script)
            } label: {
                HStack(spacing: 6) {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                    }
                    Text(isRunning ? "Running..." : "Run Script")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(DesignTokens.Colors.statusConnected)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isRunning)

            // Edit
            Button {
                editingScript = script
                showEditorSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                    Text("Edit")
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.Colors.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Schedule
            Button {
                scheduleInput = script.scheduleDescription
                showScheduleAlert = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("Schedule")
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color(NSColor.controlBackgroundColor))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.Colors.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Duplicate
            Button {
                store.duplicateScript(script)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .frame(width: 32, height: 32)
                    .background(Color(NSColor.controlBackgroundColor))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
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
                    .font(.system(size: 13))
                    .frame(width: 32, height: 32)
                    .background(Color(NSColor.controlBackgroundColor))
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.Colors.statusError.opacity(0.6), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("删除脚本")

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - 代码区

    private func codePanel(script: Script) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 区域标题
            Text("Script Content")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()
                .overlay(Color(hex: "#333333"))

            // 代码内容（只读）
            ScrollView([.vertical, .horizontal]) {
                Text(script.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color(hex: "#D4D4D4"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(hex: "#1E1E1E"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 执行日志区

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            Text("Execution Log")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()
                .overlay(Color(hex: "#333333"))

            if executionLogs.isEmpty {
                // 空状态
                VStack(spacing: 8) {
                    Text(">_")
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                        .foregroundColor(Color(hex: "#555555"))
                    Text("No execution logs yet")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#666666"))
                    Text("Run the script to see output")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#555555"))
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
                        .padding(12)
                    }
                    .onChange(of: executionLogs.count) { _ in
                        if let last = executionLogs.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(hex: "#1E1E1E"))
        .frame(maxHeight: .infinity)
        .frame(width: 320)
    }

    private func logLine(_ entry: ScriptLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "#666666"))
                .frame(width: 70, alignment: .trailing)
            Text(entry.output)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(entry.isError ? Color(hex: "#FF6B6B") : Color(hex: "#D4D4D4"))
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .id(entry.id)
    }

    // MARK: - 空状态（未选中脚本）

    private var emptyDetailState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("从左侧选择一个脚本")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow)
    }

    // MARK: - 运行脚本

    private func runScript(_ script: Script) {
        guard !isRunning else { return }

        isRunning = true
        executionLogs = []

        // 追加开始日志
        appendLog("$ \(script.name)")
        appendLog("Sending script to active terminal session...")

        // 通过通知发送脚本到活跃终端
        NotificationCenter.default.post(
            name: .runScriptRequested,
            object: nil,
            userInfo: ["scriptContent": script.content, "scriptName": script.name]
        )

        // 模拟执行反馈
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                appendLog("Script sent to terminal. Check the terminal for output.")
                isRunning = false
            }
        }
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
