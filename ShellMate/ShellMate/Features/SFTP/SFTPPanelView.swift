import SwiftUI
import AppKit

// MARK: - SFTP 面板视图（双栏文件管理器）

/// 文件传输双栏面板：左侧本地浏览器 + 右侧远程 SFTP 浏览器
struct SFTPPanelView: View {

    // MARK: - 属性

    @StateObject private var vm: SFTPPanelViewModel

    /// 终端 PWD 同步目录（来自 TerminalController.currentRemoteDirectory）
    var syncDirectory: String? = nil

    // MARK: - 初始化

    init(sftpSession: SFTPSession,
         transferQueue: SFTPTransferQueue,
         sessionName: String = "",
         syncDirectory: String? = nil,
         onClose: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: SFTPPanelViewModel(
            sftpSession: sftpSession,
            transferQueue: transferQueue,
            sessionName: sessionName
        ))
        self.syncDirectory = syncDirectory
        self._onClose = State(initialValue: onClose)
    }

    @State private var onClose: () -> Void = {}
    @State private var uploadHovered: Bool = false
    @State private var downloadHovered: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            titleBarView
            Divider()
            HStack(spacing: 0) {
                localPanelView
                // Figma 15:9: bg-[rgba(0,0,0,0.08)] w-[0.5px]
                Rectangle().fill(Color.black.opacity(0.08)).frame(width: 0.5)
                remotePanelView
            }
            Divider()
            bottomStatusBar
            if vm.showTransferPanel || vm.transferQueue.hasActiveTransfers {
                Divider()
                SFTPTransferProgressView(queue: vm.transferQueue)
                    .frame(height: 120)
            }
        }
        // Figma 15:2: bg-[#fafafb]（亮色纯色近白；深色复用 surfaceCard #131922）
        .background(Color(nsColor: NSColor(name: nil) { traits in
            traits.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: 0.075, green: 0.098, blue: 0.133, alpha: 1)  // #131922
                : NSColor(srgbRed: 0.980, green: 0.980, blue: 0.984, alpha: 1)  // #fafafb
        }))
        .onAppear { vm.onAppear() }
        .onChange(of: syncDirectory) { vm.syncRemoteDirectoryIfNeeded($0) }
        .sheet(isPresented: $vm.showNewLocalFolderDialog) { newLocalFolderSheet }
        .sheet(isPresented: $vm.showNewRemoteFolderDialog) { newRemoteFolderSheet }
        .sheet(isPresented: $vm.showRemoteRenameDialog) {
            if let target = vm.renameTarget { remoteRenameSheet(target: target) }
        }
        .sheet(isPresented: $vm.showPermissionsDialog) {
            if let target = vm.permissionsTarget { permissionsSheet(target: target) }
        }
    }

    // MARK: - 标题栏

    private var titleBarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            (Text(verbatim: "⇅  ") + Text("文件传输"))
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            Button(action: vm.performUpload) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "arrow.up")
                        .font(DesignTokens.Typography.captionLarge)
                    Text("上传")
                        .font(DesignTokens.Typography.bodySmall)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.micro)
                .background(uploadHovered ? Color.black.opacity(0.05) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundColor(vm.canUpload ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textDisabled)
            .disabled(!vm.canUpload)
            .help("将选中的本地文件上传到远程目录")
            .onHover { uploadHovered = $0 }

            Button(action: vm.performDownload) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "arrow.down")
                        .font(DesignTokens.Typography.captionLarge)
                    Text("下载")
                        .font(DesignTokens.Typography.bodySmall)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.micro)
                .background(downloadHovered ? Color.black.opacity(0.05) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundColor(vm.canDownload ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textDisabled)
            .disabled(!vm.canDownload)
            .help("将选中的远程文件下载到本地目录")
            .onHover { downloadHovered = $0 }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 36)
        // Figma 15:2 标题区无特殊背景，继承根 #fafafb
        .background(Color.clear)
    }

    // MARK: - 本地面板

    private var localPanelView: some View {
        VStack(spacing: 0) {
            panelHeader(
                icon: "internaldrive",
                iconColor: DesignTokens.Colors.accentPrimary,
                iconBgColor: DesignTokens.Colors.accentPrimary.opacity(0.10),
                title: "本地",
                onNewFolder: { vm.showNewLocalFolderDialog = true },
                onDelete: vm.deleteSelectedLocal
            )
            Divider()
            localPathBar
            Divider()
            localFileList
        }
    }

    // MARK: - 远程面板

    private var remotePanelView: some View {
        VStack(spacing: 0) {
            panelHeader(
                icon: "externaldrive",
                iconColor: DesignTokens.Colors.statusConnected,
                iconBgColor: DesignTokens.Colors.statusConnected.opacity(0.10),
                title: "远程",
                onNewFolder: { vm.showNewRemoteFolderDialog = true },
                onDelete: vm.deleteSelectedRemote
            )
            Divider()
            remotePathBar
            Divider()
            ZStack {
                remoteFileList
                if vm.isRemoteLoading { loadingOverlay }
                if let err = vm.remoteError { errorOverlay(message: err) }
            }
        }
    }

    // MARK: - 通用面板头

    private func panelHeader(
        icon: String,
        iconColor: Color,
        iconBgColor: Color,
        title: String,
        onNewFolder: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(iconBgColor)
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(DesignTokens.Typography.bodySmallStrong)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Spacer()
            Button(action: onNewFolder) {
                Image(systemName: "folder.badge.plus")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(ScaleButtonStyle())
            .help("新建文件夹")
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(ScaleButtonStyle())
            .help("删除选中项")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 32)
        // Figma 15:5/15:7 列头：极淡叠加 rgba(0,0,0,0.03)
        .background(Color.black.opacity(0.03))
    }

    // MARK: - 路径栏

    private var localPathBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "folder")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text(vm.localPath)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: {
                let parent = (vm.localPath as NSString).deletingLastPathComponent
                vm.loadLocalDirectory(path: parent)
            }) {
                Image(systemName: "chevron.left")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(vm.localPath == "/")
            .help("返回上一级")
            Button(action: { vm.loadLocalDirectory(path: vm.localPath) }) {
                Image(systemName: "arrow.clockwise")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(ScaleButtonStyle())
            .help("刷新")
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        // Figma: 路径栏继承根背景，极淡叠加区分层次
        .background(Color.black.opacity(0.02))
    }

    private var remotePathBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "folder")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text(vm.remotePath)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let synced = syncDirectory, synced == vm.remotePath {
                Image(systemName: "link")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.statusConnected)
                    .help("已与终端工作目录同步")
            }
            Button(action: {
                let parent = (vm.remotePath as NSString).deletingLastPathComponent
                vm.navigateRemoteTo(path: parent)
            }) {
                Image(systemName: "chevron.left")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(vm.remotePath == "/" || vm.isRemoteLoading)
            .help("返回上一级")
            Button(action: { vm.loadRemoteDirectory(path: vm.remotePath) }) {
                Image(systemName: "arrow.clockwise")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(vm.isRemoteLoading)
            .help("刷新")
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        // Figma: 路径栏继承根背景，极淡叠加区分层次
        .background(Color.black.opacity(0.02))
    }

    // MARK: - 文件列表

    private var localFileList: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.px) {
                if vm.localItems.isEmpty {
                    emptyFolderView
                } else {
                    ForEach(vm.localItems) { item in
                        LocalFileRowView(item: item, isSelected: vm.selectedLocalId == item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { vm.selectedLocalId = item.id }
                            .simultaneousGesture(TapGesture(count: 2).onEnded {
                                if item.isDirectory { vm.navigateLocalTo(path: item.path) }
                            })
                            .contextMenu { localFileContextMenu(for: item) }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
        }
    }

    private var remoteFileList: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.px) {
                    if vm.remoteItems.isEmpty && !vm.isRemoteLoading {
                        emptyFolderView
                    } else {
                        ForEach(vm.remoteItems) { item in
                            RemoteFileRowView(item: item, isSelected: vm.selectedRemoteId == item.id)
                                .contentShape(Rectangle())
                                .onTapGesture { vm.selectedRemoteId = item.id }
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    vm.handleRemoteDoubleClick(item: item)
                                })
                                .contextMenu { remoteFileContextMenu(for: item) }
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxs)
            }
            if vm.isDragTargeted { dropZoneOverlay }
        }
        .onDrop(of: [.fileURL], isTargeted: $vm.isDragTargeted) { providers in
            vm.handleDropProviders(providers)
            return true
        }
    }

    // MARK: - 底部状态栏

    private var bottomStatusBar: some View {
        HStack(spacing: 0) {
            Text("本地：\(vm.localSelectedFileCount)/\(vm.localTotalFileCount) 个文件")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.md)
            Spacer()
            Button(action: { withAnimation { vm.showTransferPanel.toggle() } }) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: vm.transferQueue.hasActiveTransfers
                          ? "arrow.up.arrow.down.circle.fill"
                          : "arrow.up.arrow.down.circle")
                        .font(DesignTokens.Typography.captionLarge)
                    if vm.transferQueue.hasActiveTransfers {
                        Text("\(vm.transferQueue.activeCount)")
                            .font(DesignTokens.Typography.codeSmall)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(vm.transferQueue.hasActiveTransfers
                ? DesignTokens.Colors.statusConnecting
                : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            Spacer()
            Text("远程：\(vm.remoteSelectedFileCount)/\(vm.remoteTotalFileCount) 个文件")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .frame(height: 28)
        // Figma 15:96 状态栏：极淡叠加 rgba(0,0,0,0.02)
        .background(Color.black.opacity(0.02))
    }

    // MARK: - 辅助视图

    private var emptyFolderView: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "folder.badge.plus")
                .font(DesignTokens.Typography.displayXLarge)
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("此目录为空")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, DesignTokens.Spacing.xxxl)
    }

    private var loadingOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView().controlSize(.regular)
            Text("正在加载...")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignTokens.Typography.displayXLarge)
                .foregroundColor(DesignTokens.Colors.statusError)
            Text(message)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            Button("重试") {
                vm.remoteError = nil
                vm.loadRemoteDirectory(path: vm.remotePath)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceCard.opacity(0.95))
    }

    private var dropZoneOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary.opacity(0.12))
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundColor(DesignTokens.Colors.accentPrimary)
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "arrow.up.doc")
                    .font(DesignTokens.Typography.displayXLarge)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                Text("拖放文件上传到此目录")
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                Text("当前路径：\(vm.remotePath)")
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .transition(.opacity)
    }

    // MARK: - 右键菜单

    @ViewBuilder
    private func localFileContextMenu(for item: LocalFileItem) -> some View {
        if !item.isDirectory {
            Button(action: { vm.uploadLocalItem(item) }) {
                Label("上传到远程", systemImage: "arrow.up.to.line")
            }
        }
        if item.isDirectory {
            Button(action: { vm.navigateLocalTo(path: item.path) }) {
                Label("进入目录", systemImage: "folder")
            }
        }
        Divider()
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        }) {
            Label("复制路径", systemImage: "doc.on.clipboard")
        }
        Button(action: { vm.showNewLocalFolderDialog = true }) {
            Label("新建文件夹…", systemImage: "folder.badge.plus")
        }
        Divider()
        Button(role: .destructive, action: { vm.deleteLocalItem(item) }) {
            Label("删除", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func remoteFileContextMenu(for item: SFTPFileItem) -> some View {
        if item.fileType == .regularFile {
            Button(action: { vm.downloadRemoteItem(item) }) {
                Label("下载到本地", systemImage: "arrow.down.to.line")
            }
        }
        if item.fileType.isDirectory {
            Button(action: { vm.navigateRemoteTo(path: item.path) }) {
                Label("进入目录", systemImage: "folder")
            }
        }
        Divider()
        Button(action: {
            vm.renameTarget = item
            vm.renameName = item.name
            vm.showRemoteRenameDialog = true
        }) {
            Label("重命名…", systemImage: "pencil")
        }
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        }) {
            Label("复制路径", systemImage: "doc.on.clipboard")
        }
        Button(action: { vm.showNewRemoteFolderDialog = true }) {
            Label("新建文件夹…", systemImage: "folder.badge.plus")
        }
        Divider()
        Button(action: {
            vm.permissionsTarget = item
            vm.permissionsInput = String(format: "%o", item.permissions)
            vm.showPermissionsDialog = true
        }) {
            Label("属性", systemImage: "info.circle")
        }
        Divider()
        Button(role: .destructive, action: { vm.deleteRemoteItem(item) }) {
            Label("删除", systemImage: "trash")
        }
    }

    // MARK: - 弹窗视图

    private var newLocalFolderSheet: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("新建本地文件夹")
                .font(DesignTokens.Typography.titleMedium)
            CustomTextField(placeholder: "文件夹名称", text: $vm.newLocalFolderName)
                .frame(width: 280)
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") { vm.showNewLocalFolderDialog = false; vm.newLocalFolderName = "" }
                    .buttonStyle(.bordered)
                Button("创建") {
                    vm.createLocalFolder(name: vm.newLocalFolderName)
                    vm.showNewLocalFolderDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.newLocalFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 340)
    }

    private var newRemoteFolderSheet: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("新建远程文件夹")
                .font(DesignTokens.Typography.titleMedium)
            CustomTextField(placeholder: "文件夹名称", text: $vm.newRemoteFolderName)
                .frame(width: 280)
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") { vm.showNewRemoteFolderDialog = false; vm.newRemoteFolderName = "" }
                    .buttonStyle(.bordered)
                Button("创建") {
                    vm.performCreateRemoteFolder(name: vm.newRemoteFolderName)
                    vm.showNewRemoteFolderDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.newRemoteFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 340)
    }

    private func remoteRenameSheet(target: SFTPFileItem) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("重命名")
                .font(DesignTokens.Typography.titleMedium)
            CustomTextField(placeholder: "新名称", text: $vm.renameName)
                .frame(width: 280)
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") { vm.showRemoteRenameDialog = false }
                    .buttonStyle(.bordered)
                Button("确认") {
                    vm.performRemoteRename(item: target, newName: vm.renameName)
                    vm.showRemoteRenameDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.renameName.trimmingCharacters(in: .whitespaces).isEmpty)
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
                Text(target.name)
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                HStack(spacing: DesignTokens.Spacing.md) {
                    Text("八进制权限：")
                        .font(DesignTokens.Typography.bodySmall)
                    CustomTextField(placeholder: "755", text: $vm.permissionsInput)
                        .frame(width: 80)
                        .font(DesignTokens.Typography.codeMedium)
                }
            }
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") { vm.showPermissionsDialog = false }
                    .buttonStyle(.bordered)
                Button("应用") {
                    vm.performSetPermissions(item: target, modeString: vm.permissionsInput)
                    vm.showPermissionsDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(UInt32(vm.permissionsInput, radix: 8) == nil)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 320)
    }
}

// MARK: - 传输进度面板

/// 传输任务进度面板（底部折叠面板）
struct SFTPTransferProgressView: View {

    @ObservedObject var queue: SFTPTransferQueue

    var body: some View {
        VStack(spacing: 0) {
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
                Button("清除已完成") { queue.clearCompleted() }
                    .buttonStyle(.plain)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .disabled(queue.items.filter { $0.state.isTerminal }.isEmpty)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            Divider()
            if queue.items.isEmpty {
                Text("无传输任务")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(queue.items) { item in
                            TransferItemRow(item: item, onCancel: { queue.cancel(item) })
                            if item.id != queue.items.last?.id { Divider() }
                        }
                    }
                }
            }
        }
        // Figma: 传输进度面板继承根背景，极淡叠加区分层次
        .background(Color.black.opacity(0.02))
    }
}

/// 单个传输任务行
private struct TransferItemRow: View {

    @ObservedObject var item: SFTPTransferItem
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: item.direction.sfSymbolName)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(directionColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
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
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxxs) {
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
            if !item.state.isTerminal {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle")
                        .font(DesignTokens.Typography.bodySmall)
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
