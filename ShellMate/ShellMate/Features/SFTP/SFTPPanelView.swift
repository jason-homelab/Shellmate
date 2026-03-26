import SwiftUI
import AppKit

// MARK: - SFTP 面板视图

/// SFTP 文件浏览面板
/// 任务 10.2 / 10.3：文件列表 + 路径导航 + 双击进入 + 上传/下载
struct SFTPPanelView: View {

    // MARK: - 属性

    let sftpSession: SFTPSession
    @ObservedObject var transferQueue: SFTPTransferQueue
    var onClose: () -> Void

    // MARK: - 状态

    @State private var currentPath: String = "/"
    @State private var pathHistory: [String] = ["/"]
    @State private var items: [SFTPFileItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedItemId: UUID?
    @State private var showRenameDialog: Bool = false
    @State private var renameTarget: SFTPFileItem?
    @State private var newName: String = ""
    @State private var showNewFolderDialog: Bool = false
    @State private var newFolderName: String = ""
    @State private var showPermissionsDialog: Bool = false
    @State private var permissionsTarget: SFTPFileItem?
    @State private var permissionsInput: String = ""
    @State private var showTransferPanel: Bool = false
    @State private var isDragTargeted: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbarView

            Divider()

            // 路径导航栏
            pathBarView

            Divider()

            // 文件列表区域
            ZStack {
                fileListView

                if isLoading {
                    loadingOverlay
                }

                if let error = errorMessage {
                    errorOverlay(message: error)
                }
            }

            // 传输进度面板（可折叠）
            if showTransferPanel || transferQueue.hasActiveTransfers {
                Divider()
                SFTPTransferProgressView(queue: transferQueue)
                    .frame(height: 120)
            }
        }
        .background(DesignTokens.Colors.surfacePanel)
        .onAppear {
            loadDirectory(path: currentPath)
        }
        // 重命名弹窗
        .sheet(isPresented: $showRenameDialog) {
            if let target = renameTarget {
                renameSheet(target: target)
            }
        }
        // 新建文件夹弹窗
        .sheet(isPresented: $showNewFolderDialog) {
            newFolderSheet
        }
        // 权限修改弹窗
        .sheet(isPresented: $showPermissionsDialog) {
            if let target = permissionsTarget {
                permissionsSheet(target: target)
            }
        }
    }

    // MARK: - 子视图

    private var toolbarView: some View {
        VStack(spacing: 0) {
            // SFTPHeader（Figma 规范：高 28pt，含标题 + 收起按钮）
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "arrow.up.arrow.down.square")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("SFTP")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Spacer()

                // 收起面板（替代 ×，使用 sidebar 收起图标）
                Button(action: onClose) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("隐藏 SFTP 面板")
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(height: 28)
            .background(DesignTokens.Colors.surfacePanel)

            Divider()

            // 操作工具栏
            HStack(spacing: DesignTokens.Spacing.xs) {
                // 返回上级
                Button(action: navigateUp) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(currentPath == "/" || isLoading)
                .help("返回上级目录")
                .foregroundColor(currentPath == "/" ? DesignTokens.Colors.textDisabled : DesignTokens.Colors.textSecondary)

                // 刷新
                Button(action: { loadDirectory(path: currentPath) }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .help("刷新")

                Divider().frame(height: 16)

                // 上传文件
                Button(action: uploadFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 11))
                        Text("上传")
                            .font(DesignTokens.Typography.labelSmall)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .disabled(isLoading)
                .help("上传文件到当前目录")

                // 下载选中文件
                Button(action: downloadSelected) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                        Text("下载")
                            .font(DesignTokens.Typography.labelSmall)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedItemId != nil ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textDisabled)
                .disabled(selectedItemId == nil || isLoading)
                .help("下载选中文件")

                Divider().frame(height: 16)

                // 新建文件夹
                Button(action: { showNewFolderDialog = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .help("新建文件夹")

                Spacer()

                // 传输进度切换
                Button(action: { withAnimation { showTransferPanel.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: transferQueue.hasActiveTransfers ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                            .font(.system(size: 11))
                        if transferQueue.hasActiveTransfers {
                            Text("\(transferQueue.activeCount)")
                                .font(DesignTokens.Typography.codeSmall)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(transferQueue.hasActiveTransfers
                    ? DesignTokens.Colors.statusConnecting
                    : DesignTokens.Colors.textSecondary)
                .help("传输队列")
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.surfacePanel)
        }
    }

    private var pathBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                let components = pathComponents(for: currentPath)
                ForEach(Array(components.enumerated()), id: \.offset) { item in
                    let index = item.offset
                    let name = item.element.0
                    let path = item.element.1
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    Button(action: { navigateTo(path: path) }) {
                        Text(name.isEmpty ? "/" : name)
                            .font(DesignTokens.Typography.codeSmall)
                            .foregroundColor(index == components.count - 1
                                ? DesignTokens.Colors.textPrimary
                                : DesignTokens.Colors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .background(DesignTokens.Colors.surfaceWindow)
    }

    private var fileListView: some View {
        ZStack {
            List(selection: $selectedItemId) {
                if items.isEmpty && !isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 28))
                            .foregroundColor(DesignTokens.Colors.textDisabled)
                            .opacity(0.4)
                        Text("此目录为空")
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textDisabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignTokens.Spacing.xxxl)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(items) { item in
                        SFTPFileRowView(item: item)
                            .tag(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                handleDoubleClick(item: item)
                            }
                            .contextMenu {
                                fileContextMenu(for: item)
                            }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            // 拖拽 Drop Zone 覆盖层
            if isDragTargeted {
                dropZoneOverlay
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDropProviders(providers)
            return true
        }
    }

    private var dropZoneOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.Colors.accentPrimary.opacity(0.12))
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .foregroundColor(DesignTokens.Colors.accentPrimary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)

                Text("拖放文件上传到此目录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)

                Text("当前路径：\(currentPath)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .transition(.opacity)
    }

    private func handleDropProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let remotePath = currentPath.hasSuffix("/")
                    ? "\(currentPath)\(url.lastPathComponent)"
                    : "\(currentPath)/\(url.lastPathComponent)"
                DispatchQueue.main.async {
                    transferQueue.enqueueUpload(localPath: url.path, remotePath: remotePath)
                    showTransferPanel = true
                }
            }
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .controlSize(.regular)
            Text("正在加载...")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfacePanel.opacity(0.8))
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Colors.statusError)

            Text(message)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)

            Button("重试") {
                errorMessage = nil
                loadDirectory(path: currentPath)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfacePanel.opacity(0.95))
    }

    // MARK: - 右键菜单

    @ViewBuilder
    private func fileContextMenu(for item: SFTPFileItem) -> some View {
        // 下载（仅文件）
        if item.fileType == .regularFile {
            Button(action: { downloadItem(item) }) {
                Label("下载到本地", systemImage: "arrow.down.to.line")
            }
        }
        // 进入目录
        if item.fileType.isDirectory {
            Button(action: { navigateTo(path: item.path) }) {
                Label("进入目录", systemImage: "folder.fill")
            }
        }

        Divider()

        Button(action: {
            renameTarget = item
            newName = item.name
            showRenameDialog = true
        }) {
            Label("重命名…", systemImage: "pencil")
        }

        Button(action: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(item.path, forType: .string)
        }) {
            Label("复制路径", systemImage: "doc.on.clipboard")
        }

        Button(action: { showNewFolderDialog = true }) {
            Label("新建文件夹…", systemImage: "folder.badge.plus")
        }

        Divider()

        Button(action: {
            permissionsTarget = item
            permissionsInput = String(format: "%o", item.permissions)
            showPermissionsDialog = true
        }) {
            Label("属性", systemImage: "info.circle")
        }

        Divider()

        Button(role: .destructive, action: { deleteItem(item) }) {
            Label("删除", systemImage: "trash")
        }
    }

    // MARK: - 弹窗视图

    private func renameSheet(target: SFTPFileItem) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("重命名")
                .font(DesignTokens.Typography.titleMedium)

            TextField("新名称", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") { showRenameDialog = false }
                    .buttonStyle(.bordered)
                Button("确认") {
                    performRename(item: target, newName: newName)
                    showRenameDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 340)
    }

    private var newFolderSheet: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("新建文件夹")
                .font(DesignTokens.Typography.titleMedium)

            TextField("文件夹名称", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") { showNewFolderDialog = false }
                    .buttonStyle(.bordered)
                Button("创建") {
                    performCreateFolder(name: newFolderName)
                    showNewFolderDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 340)
    }

    private func permissionsSheet(target: SFTPFileItem) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("修改权限")
                .font(DesignTokens.Typography.titleMedium)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("\(target.name)")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                HStack(spacing: DesignTokens.Spacing.md) {
                    Text("八进制权限：")
                        .font(DesignTokens.Typography.bodySmall)
                    TextField("755", text: $permissionsInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .font(DesignTokens.Typography.codeMedium)
                }
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") { showPermissionsDialog = false }
                    .buttonStyle(.bordered)
                Button("应用") {
                    performSetPermissions(item: target, modeString: permissionsInput)
                    showPermissionsDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(UInt32(permissionsInput, radix: 8) == nil)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 320)
    }

    // MARK: - 方法

    private func loadDirectory(path: String) {
        isLoading = true
        errorMessage = nil
        selectedItemId = nil

        Task {
            do {
                let result = try await sftpSession.listDirectory(path: path)
                await MainActor.run {
                    items = result
                    currentPath = path
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func navigateTo(path: String) {
        guard path != currentPath else { return }
        if pathHistory.last != currentPath {
            pathHistory.append(currentPath)
        }
        loadDirectory(path: path)
    }

    private func navigateUp() {
        guard currentPath != "/" else { return }
        let parentPath = String(currentPath.dropLast(currentPath.hasSuffix("/") ? 1 : 0)
            .components(separatedBy: "/").dropLast().joined(separator: "/"))
        navigateTo(path: parentPath.isEmpty ? "/" : parentPath)
    }

    private func handleDoubleClick(item: SFTPFileItem) {
        if item.fileType.isDirectory {
            navigateTo(path: item.path)
        } else {
            downloadItem(item)
        }
    }

    private func uploadFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.title = "选择要上传的文件"

        if panel.runModal() == .OK {
            for url in panel.urls {
                let localPath = url.path
                let remotePath = currentPath.hasSuffix("/")
                    ? "\(currentPath)\(url.lastPathComponent)"
                    : "\(currentPath)/\(url.lastPathComponent)"
                transferQueue.enqueueUpload(localPath: localPath, remotePath: remotePath)
                showTransferPanel = true
            }
        }
    }

    private func downloadSelected() {
        guard let selectedId = selectedItemId,
              let item = items.first(where: { $0.id == selectedId }),
              item.fileType == .regularFile else { return }
        downloadItem(item)
    }

    private func downloadItem(_ item: SFTPFileItem) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.name
        panel.title = "保存文件"

        if panel.runModal() == .OK, let url = panel.url {
            transferQueue.enqueueDownload(
                remotePath: item.path,
                localPath: url.path,
                fileSize: item.size
            )
            showTransferPanel = true
        }
    }

    private func deleteItem(_ item: SFTPFileItem) {
        Task {
            do {
                if item.fileType.isDirectory {
                    try await sftpSession.deleteDirectory(path: item.path)
                } else {
                    try await sftpSession.deleteFile(path: item.path)
                }
                loadDirectory(path: currentPath)
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func performRename(item: SFTPFileItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let parentPath = item.path.components(separatedBy: "/").dropLast().joined(separator: "/")
        let destPath = "\(parentPath)/\(trimmed)"

        Task {
            do {
                try await sftpSession.renameFile(from: item.path, to: destPath)
                loadDirectory(path: currentPath)
            } catch {
                await MainActor.run {
                    errorMessage = "重命名失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func performCreateFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newPath = currentPath.hasSuffix("/")
            ? "\(currentPath)\(trimmed)"
            : "\(currentPath)/\(trimmed)"

        Task {
            do {
                try await sftpSession.createDirectory(path: newPath)
                loadDirectory(path: currentPath)
            } catch {
                await MainActor.run {
                    errorMessage = "创建文件夹失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func performSetPermissions(item: SFTPFileItem, modeString: String) {
        guard let mode = UInt32(modeString, radix: 8) else { return }
        Task {
            do {
                try await sftpSession.setPermissions(path: item.path, mode: mode)
                loadDirectory(path: currentPath)
            } catch {
                await MainActor.run {
                    errorMessage = "修改权限失败：\(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 辅助

    private func pathComponents(for path: String) -> [(name: String, path: String)] {
        var components: [(name: String, path: String)] = [("", "/")]
        let parts = path.components(separatedBy: "/").filter { !$0.isEmpty }
        var accumulated = ""
        for part in parts {
            accumulated += "/" + part
            components.append((name: part, path: accumulated))
        }
        return components
    }
}

// MARK: - 文件行视图

/// 单个文件/目录行
struct SFTPFileRowView: View {

    let item: SFTPFileItem

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 文件类型图标
            Image(systemName: item.fileType.sfSymbolName)
                .font(.system(size: 13))
                .foregroundColor(iconColor)
                .frame(width: 18, alignment: .center)

            // 文件名（flex，确保始终有足够显示空间）
            Text(item.name)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 40, maxWidth: .infinity, alignment: .leading)

            // 文件大小
            Text(item.formattedSize)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 54, alignment: .trailing)

            // 修改时间（移除权限列，腾出空间给文件名）
            Text(item.formattedDate)
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.vertical, 1)
        .help(item.name + "  " + item.permissionsString)
    }

    private var iconColor: Color {
        switch item.fileType {
        case .directory:    return DesignTokens.Colors.statusConnecting
        case .regularFile:  return DesignTokens.Colors.textSecondary
        case .symlink:      return DesignTokens.Colors.accentPrimary
        case .other:        return DesignTokens.Colors.textTertiary
        }
    }
}

// MARK: - 传输进度面板

/// 传输任务进度面板（底部折叠面板）
struct SFTPTransferProgressView: View {

    @ObservedObject var queue: SFTPTransferQueue

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("传输队列")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                if queue.hasActiveTransfers {
                    Text("·")
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text("\(queue.activeCount) 传输中")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.statusConnecting)
                }

                Spacer()

                Button("清除已完成") {
                    queue.clearCompleted()
                }
                .buttonStyle(.plain)
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .disabled(queue.items.filter { $0.state.isTerminal }.isEmpty)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)

            Divider()

            // 传输列表
            if queue.items.isEmpty {
                Text("无传输任务")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(queue.items) { item in
                            TransferItemRow(item: item, onCancel: {
                                queue.cancel(item)
                            })
                            if item.id != queue.items.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .background(DesignTokens.Colors.surfaceWindow)
    }
}

/// 单个传输任务行
private struct TransferItemRow: View {

    @ObservedObject var item: SFTPTransferItem
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 方向图标
            Image(systemName: item.direction.sfSymbolName)
                .font(.system(size: 12))
                .foregroundColor(directionColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                if item.state == .inProgress {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .tint(DesignTokens.Colors.accentPrimary)
                } else {
                    Text(item.state.displayName)
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(stateColor)
                }
            }

            Spacer()

            // 速度/大小信息
            VStack(alignment: .trailing, spacing: 2) {
                if item.state == .inProgress {
                    if item.bytesPerSecond > 0 {
                        Text(formatSpeed(item.bytesPerSecond))
                            .font(DesignTokens.Typography.codeSmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    Text("\(Int(item.progress * 100))%")
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .frame(width: 60, alignment: .trailing)

            // 取消按钮
            if !item.state.isTerminal {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var directionColor: Color {
        switch item.direction {
        case .upload:   return DesignTokens.Colors.statusConnecting
        case .download: return DesignTokens.Colors.statusConnected
        }
    }

    private var stateColor: Color {
        switch item.state {
        case .completed:    return DesignTokens.Colors.statusConnected
        case .failed:       return DesignTokens.Colors.statusError
        case .cancelled:    return DesignTokens.Colors.textTertiary
        default:            return DesignTokens.Colors.textSecondary
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let speed = Int64(bytesPerSecond)
        return "\(ByteCountFormatter.string(fromByteCount: speed, countStyle: .file))/s"
    }
}
