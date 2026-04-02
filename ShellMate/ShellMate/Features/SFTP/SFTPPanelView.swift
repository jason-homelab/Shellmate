import SwiftUI
import AppKit

// MARK: - SFTP 面板视图（双栏文件管理器）

/// 文件传输双栏面板：左侧本地浏览器 + 右侧远程 SFTP 浏览器
struct SFTPPanelView: View {

    // MARK: - 属性

    let sftpSession: SFTPSession
    @ObservedObject var transferQueue: SFTPTransferQueue
    var sessionName: String = ""
    var onClose: () -> Void

    // MARK: - 本地文件状态

    @State private var localPath: String = NSHomeDirectory()
    @State private var localItems: [LocalFileItem] = []
    @State private var selectedLocalId: UUID?

    // MARK: - 远程文件状态

    @State private var remotePath: String = "/"
    @State private var remoteItems: [SFTPFileItem] = []
    @State private var isRemoteLoading: Bool = false
    @State private var remoteError: String?
    @State private var selectedRemoteId: UUID?

    // MARK: - 拖放

    @State private var isDragTargeted: Bool = false

    // MARK: - 传输面板

    @State private var showTransferPanel: Bool = false

    // MARK: - 弹窗状态

    @State private var showNewLocalFolderDialog: Bool = false
    @State private var newLocalFolderName: String = ""
    @State private var showNewRemoteFolderDialog: Bool = false
    @State private var newRemoteFolderName: String = ""
    @State private var showRemoteRenameDialog: Bool = false
    @State private var renameTarget: SFTPFileItem?
    @State private var renameName: String = ""
    @State private var showPermissionsDialog: Bool = false
    @State private var permissionsTarget: SFTPFileItem?
    @State private var permissionsInput: String = ""

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            titleBarView
            Divider()
            HStack(spacing: 0) {
                localPanelView
                Divider()
                remotePanelView
            }
            Divider()
            bottomStatusBar
            if showTransferPanel || transferQueue.hasActiveTransfers {
                Divider()
                SFTPTransferProgressView(queue: transferQueue)
                    .frame(height: 120)
            }
        }
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.50))
        .onAppear {
            loadLocalDirectory(path: localPath)
            loadRemoteDirectory(path: remotePath)
        }
        .sheet(isPresented: $showNewLocalFolderDialog) { newLocalFolderSheet }
        .sheet(isPresented: $showNewRemoteFolderDialog) { newRemoteFolderSheet }
        .sheet(isPresented: $showRemoteRenameDialog) {
            if let target = renameTarget { remoteRenameSheet(target: target) }
        }
        .sheet(isPresented: $showPermissionsDialog) {
            if let target = permissionsTarget { permissionsSheet(target: target) }
        }
    }

    // MARK: - 标题栏

    private var titleBarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(sessionName.isEmpty ? "文件传输" : "文件传输 — \(sessionName)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button(action: performUpload) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                    Text("上传")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundColor(canUpload
                ? DesignTokens.Colors.textSecondary
                : DesignTokens.Colors.textDisabled)
            .disabled(!canUpload)
            .help("将选中的本地文件上传到远程目录")

            Button(action: performDownload) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11))
                    Text("下载")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundColor(canDownload
                ? DesignTokens.Colors.textSecondary
                : DesignTokens.Colors.textDisabled)
            .disabled(!canDownload)
            .help("将选中的远程文件下载到本地目录")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 36)
        .background(Color.white.opacity(0.60))
        .background(.ultraThinMaterial)
    }

    // MARK: - 本地面板

    private var localPanelView: some View {
        VStack(spacing: 0) {
            panelHeader(
                icon: "internaldrive",
                iconColor: DesignTokens.Colors.accentPrimary,
                iconBgColor: Color(hex: "#007aff").opacity(0.10),
                title: "本地",
                onNewFolder: { showNewLocalFolderDialog = true },
                onDelete: deleteSelectedLocal
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
                icon: "externaldrive.fill",
                iconColor: DesignTokens.Colors.statusConnected,
                iconBgColor: Color(hex: "#34c759").opacity(0.10),
                title: "远程",
                onNewFolder: { showNewRemoteFolderDialog = true },
                onDelete: deleteSelectedRemote
            )
            Divider()
            remotePathBar
            Divider()
            ZStack {
                remoteFileList
                if isRemoteLoading { loadingOverlay }
                if let err = remoteError { errorOverlay(message: err) }
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
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconBgColor)
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            Button(action: onNewFolder) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color.black.opacity(0.0))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("新建文件夹")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color.black.opacity(0.0))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("删除选中项")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 32)
        .background(Color.white.opacity(0.60))
        .background(.ultraThinMaterial)
    }

    // MARK: - 路径栏

    private var localPathBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "house")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text(localPath)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 返回上一级
            Button(action: {
                let parent = (localPath as NSString).deletingLastPathComponent
                loadLocalDirectory(path: parent)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(localPath == "/")
            .help("返回上一级")

            Button(action: { loadLocalDirectory(path: localPath) }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("刷新")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.60))
    }

    private var remotePathBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "house")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text(remotePath)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 返回上一级
            Button(action: {
                let parent = (remotePath as NSString).deletingLastPathComponent
                navigateRemoteTo(path: parent)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(remotePath == "/" || isRemoteLoading)
            .help("返回上一级")

            Button(action: { loadRemoteDirectory(path: remotePath) }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(isRemoteLoading)
            .help("刷新")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.60))
    }

    // MARK: - 本地文件列表

    private var localFileList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                if localItems.isEmpty {
                    emptyFolderView
                } else {
                    ForEach(localItems) { item in
                        LocalFileRowView(item: item, isSelected: selectedLocalId == item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedLocalId = item.id }
                            .simultaneousGesture(TapGesture(count: 2).onEnded {
                                if item.isDirectory { navigateLocalTo(path: item.path) }
                            })
                            .contextMenu { localFileContextMenu(for: item) }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    // MARK: - 远程文件列表

    private var remoteFileList: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 1) {
                    if remoteItems.isEmpty && !isRemoteLoading {
                        emptyFolderView
                    } else {
                        ForEach(remoteItems) { item in
                            RemoteFileRowView(item: item, isSelected: selectedRemoteId == item.id)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedRemoteId = item.id }
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    handleRemoteDoubleClick(item: item)
                                })
                                .contextMenu { remoteFileContextMenu(for: item) }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            if isDragTargeted { dropZoneOverlay }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDropProviders(providers)
            return true
        }
    }

    // MARK: - 底部状态栏

    private var bottomStatusBar: some View {
        HStack(spacing: 0) {
            Text("本地：\(localSelectedFileCount)/\(localTotalFileCount) 个文件")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.md)

            Spacer()

            Button(action: { withAnimation { showTransferPanel.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: transferQueue.hasActiveTransfers
                          ? "arrow.up.arrow.down.circle.fill"
                          : "arrow.up.arrow.down.circle")
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
                : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.sm)

            Spacer()

            Text("远程：\(remoteSelectedFileCount)/\(remoteTotalFileCount) 个文件")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .frame(height: 28)
        .background(Color.white.opacity(0.60))
        .background(.ultraThinMaterial)
    }

    // MARK: - 辅助视图

    private var emptyFolderView: some View {
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
    }

    private var loadingOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView().controlSize(.regular)
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
                remoteError = nil
                loadRemoteDirectory(path: remotePath)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfacePanel.opacity(0.95))
    }

    private var dropZoneOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary.opacity(0.12))
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .foregroundColor(DesignTokens.Colors.accentPrimary)
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                Text("拖放文件上传到此目录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                Text("当前路径：\(remotePath)")
                    .font(.system(size: 10, design: .monospaced))
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
            Button(action: { uploadLocalItem(item) }) {
                Label("上传到远程", systemImage: "arrow.up.to.line")
            }
        }
        if item.isDirectory {
            Button(action: { navigateLocalTo(path: item.path) }) {
                Label("进入目录", systemImage: "folder.fill")
            }
        }
        Divider()
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        }) {
            Label("复制路径", systemImage: "doc.on.clipboard")
        }
        Button(action: { showNewLocalFolderDialog = true }) {
            Label("新建文件夹…", systemImage: "folder.badge.plus")
        }
        Divider()
        Button(role: .destructive, action: { deleteLocalItem(item) }) {
            Label("删除", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func remoteFileContextMenu(for item: SFTPFileItem) -> some View {
        if item.fileType == .regularFile {
            Button(action: { downloadRemoteItem(item) }) {
                Label("下载到本地", systemImage: "arrow.down.to.line")
            }
        }
        if item.fileType.isDirectory {
            Button(action: { navigateRemoteTo(path: item.path) }) {
                Label("进入目录", systemImage: "folder.fill")
            }
        }
        Divider()
        Button(action: {
            renameTarget = item
            renameName = item.name
            showRemoteRenameDialog = true
        }) {
            Label("重命名…", systemImage: "pencil")
        }
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        }) {
            Label("复制路径", systemImage: "doc.on.clipboard")
        }
        Button(action: { showNewRemoteFolderDialog = true }) {
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
        Button(role: .destructive, action: { deleteRemoteItem(item) }) {
            Label("删除", systemImage: "trash")
        }
    }

    // MARK: - 弹窗视图

    private var newLocalFolderSheet: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("新建本地文件夹")
                .font(DesignTokens.Typography.titleMedium)
            TextField("文件夹名称", text: $newLocalFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") {
                    showNewLocalFolderDialog = false
                    newLocalFolderName = ""
                }
                .buttonStyle(.bordered)
                Button("创建") {
                    createLocalFolder(name: newLocalFolderName)
                    showNewLocalFolderDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newLocalFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 340)
    }

    private var newRemoteFolderSheet: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("新建远程文件夹")
                .font(DesignTokens.Typography.titleMedium)
            TextField("文件夹名称", text: $newRemoteFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") {
                    showNewRemoteFolderDialog = false
                    newRemoteFolderName = ""
                }
                .buttonStyle(.bordered)
                Button("创建") {
                    performCreateRemoteFolder(name: newRemoteFolderName)
                    showNewRemoteFolderDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newRemoteFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 340)
    }

    private func remoteRenameSheet(target: SFTPFileItem) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("重命名")
                .font(DesignTokens.Typography.titleMedium)
            TextField("新名称", text: $renameName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") { showRemoteRenameDialog = false }
                    .buttonStyle(.bordered)
                Button("确认") {
                    performRemoteRename(item: target, newName: renameName)
                    showRemoteRenameDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameName.trimmingCharacters(in: .whitespaces).isEmpty)
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

    // MARK: - 计算属性

    private var canUpload: Bool {
        guard let id = selectedLocalId,
              let item = localItems.first(where: { $0.id == id }) else { return false }
        return !item.isDirectory
    }

    private var canDownload: Bool {
        guard let id = selectedRemoteId,
              let item = remoteItems.first(where: { $0.id == id }) else { return false }
        return item.fileType == .regularFile
    }

    private var localTotalFileCount: Int {
        localItems.filter { !$0.isDirectory }.count
    }

    private var localSelectedFileCount: Int {
        guard let id = selectedLocalId,
              let item = localItems.first(where: { $0.id == id }),
              !item.isDirectory else { return 0 }
        return 1
    }

    private var remoteTotalFileCount: Int {
        remoteItems.filter { $0.fileType == .regularFile }.count
    }

    private var remoteSelectedFileCount: Int {
        guard let id = selectedRemoteId,
              let item = remoteItems.first(where: { $0.id == id }),
              item.fileType == .regularFile else { return 0 }
        return 1
    }

    // MARK: - 本地文件操作

    private func loadLocalDirectory(path: String) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return }

        var items: [LocalFileItem] = []

        // ".." 上级目录项（根目录除外）
        if path != "/" {
            let parent = (path as NSString).deletingLastPathComponent
            items.append(LocalFileItem(name: "..", path: parent, isDirectory: true))
        }

        // 过滤隐藏文件，排序：目录优先 → 名称升序
        let visible = contents.filter { !$0.hasPrefix(".") }
        let sorted = visible.sorted { a, b in
            let aPath = path.hasSuffix("/") ? "\(path)\(a)" : "\(path)/\(a)"
            let bPath = path.hasSuffix("/") ? "\(path)\(b)" : "\(path)/\(b)"
            let aIsDir = (try? fm.attributesOfItem(atPath: aPath)[.type] as? FileAttributeType) == .typeDirectory
            let bIsDir = (try? fm.attributesOfItem(atPath: bPath)[.type] as? FileAttributeType) == .typeDirectory
            if aIsDir != bIsDir { return aIsDir }
            return a.localizedStandardCompare(b) == .orderedAscending
        }

        for name in sorted {
            let fullPath = path.hasSuffix("/") ? "\(path)\(name)" : "\(path)/\(name)"
            let attrs = try? fm.attributesOfItem(atPath: fullPath)
            let isDir = (attrs?[.type] as? FileAttributeType) == .typeDirectory
            let size = (attrs?[.size] as? UInt64) ?? 0
            let modDate = attrs?[.modificationDate] as? Date
            items.append(LocalFileItem(name: name, path: fullPath, isDirectory: isDir, size: size, modifiedAt: modDate))
        }

        localItems = items
        localPath = path
        selectedLocalId = nil
    }

    private func navigateLocalTo(path: String) {
        loadLocalDirectory(path: path)
    }

    private func deleteSelectedLocal() {
        guard let id = selectedLocalId,
              let item = localItems.first(where: { $0.id == id }) else { return }
        deleteLocalItem(item)
    }

    private func deleteLocalItem(_ item: LocalFileItem) {
        guard item.name != ".." else { return }
        try? FileManager.default.removeItem(atPath: item.path)
        loadLocalDirectory(path: localPath)
    }

    private func createLocalFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newPath = localPath.hasSuffix("/") ? "\(localPath)\(trimmed)" : "\(localPath)/\(trimmed)"
        try? FileManager.default.createDirectory(atPath: newPath, withIntermediateDirectories: false)
        loadLocalDirectory(path: localPath)
        newLocalFolderName = ""
    }

    private func uploadLocalItem(_ item: LocalFileItem) {
        guard !item.isDirectory else { return }
        let dest = remotePath.hasSuffix("/")
            ? "\(remotePath)\(item.name)"
            : "\(remotePath)/\(item.name)"
        transferQueue.enqueueUpload(localPath: item.path, remotePath: dest)
        showTransferPanel = true
    }

    // MARK: - 远程文件操作

    private func loadRemoteDirectory(path: String) {
        isRemoteLoading = true
        remoteError = nil
        selectedRemoteId = nil

        Task {
            do {
                let result = try await sftpSession.listDirectory(path: path)
                await MainActor.run {
                    var items = result
                    // 非根目录时在列表首部插入 ".." 返回上级目录项
                    if path != "/" {
                        let parent = (path as NSString).deletingLastPathComponent
                        let parentItem = SFTPFileItem(name: "..", path: parent, fileType: .directory)
                        items.insert(parentItem, at: 0)
                    }
                    remoteItems = items
                    remotePath = path
                    isRemoteLoading = false
                }
            } catch {
                await MainActor.run {
                    remoteError = error.localizedDescription
                    isRemoteLoading = false
                }
            }
        }
    }

    private func navigateRemoteTo(path: String) {
        let normalized = sanitizeRemotePath(path)
        guard !normalized.isEmpty, normalized != remotePath else { return }
        loadRemoteDirectory(path: normalized)
    }

    private func handleRemoteDoubleClick(item: SFTPFileItem) {
        if item.fileType.isDirectory {
            navigateRemoteTo(path: item.path)
        } else {
            downloadRemoteItem(item)
        }
    }

    private func deleteSelectedRemote() {
        guard let id = selectedRemoteId,
              let item = remoteItems.first(where: { $0.id == id }) else { return }
        deleteRemoteItem(item)
    }

    private func deleteRemoteItem(_ item: SFTPFileItem) {
        Task {
            do {
                if item.fileType.isDirectory {
                    try await sftpSession.deleteDirectory(path: item.path)
                } else {
                    try await sftpSession.deleteFile(path: item.path)
                }
                loadRemoteDirectory(path: remotePath)
            } catch {
                await MainActor.run {
                    remoteError = "删除失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func downloadRemoteItem(_ item: SFTPFileItem) {
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

    private func performRemoteRename(item: SFTPFileItem, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let parent = item.path.components(separatedBy: "/").dropLast().joined(separator: "/")
        let destPath = "\(parent)/\(trimmed)"
        Task {
            do {
                try await sftpSession.renameFile(from: item.path, to: destPath)
                loadRemoteDirectory(path: remotePath)
            } catch {
                await MainActor.run {
                    remoteError = "重命名失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func performCreateRemoteFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newPath = remotePath.hasSuffix("/") ? "\(remotePath)\(trimmed)" : "\(remotePath)/\(trimmed)"
        Task {
            do {
                try await sftpSession.createDirectory(path: newPath)
                loadRemoteDirectory(path: remotePath)
            } catch {
                await MainActor.run {
                    remoteError = "创建文件夹失败：\(error.localizedDescription)"
                }
            }
        }
        newRemoteFolderName = ""
    }

    private func performSetPermissions(item: SFTPFileItem, modeString: String) {
        guard let mode = UInt32(modeString, radix: 8) else { return }
        Task {
            do {
                try await sftpSession.setPermissions(path: item.path, mode: mode)
                loadRemoteDirectory(path: remotePath)
            } catch {
                await MainActor.run {
                    remoteError = "修改权限失败：\(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 顶栏操作

    private func performUpload() {
        guard canUpload,
              let id = selectedLocalId,
              let item = localItems.first(where: { $0.id == id }) else { return }
        uploadLocalItem(item)
    }

    private func performDownload() {
        guard canDownload,
              let id = selectedRemoteId,
              let item = remoteItems.first(where: { $0.id == id }) else { return }
        downloadRemoteItem(item)
    }

    private func handleDropProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let dest = self.remotePath.hasSuffix("/")
                    ? "\(self.remotePath)\(url.lastPathComponent)"
                    : "\(self.remotePath)/\(url.lastPathComponent)"
                DispatchQueue.main.async {
                    self.transferQueue.enqueueUpload(localPath: url.path, remotePath: dest)
                    self.showTransferPanel = true
                }
            }
        }
    }

    // MARK: - 路径规范化

    private func sanitizeRemotePath(_ rawPath: String) -> String {
        let isAbsolute = rawPath.hasPrefix("/")
        let components = rawPath.components(separatedBy: "/").filter { !$0.isEmpty }
        var resolved: [String] = []
        for component in components {
            switch component {
            case ".":  break
            case "..": if !resolved.isEmpty { resolved.removeLast() }
            default:   resolved.append(component)
            }
        }
        let joined = resolved.joined(separator: "/")
        return isAbsolute ? "/\(joined)" : (joined.isEmpty ? "/" : joined)
    }
}

// MARK: - 本地文件行视图

/// 本地文件/目录行（双行布局：文件名 + 大小+时间）
struct LocalFileRowView: View {

    let item: LocalFileItem
    let isSelected: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // 图标容器
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(item.isDirectory
                        ? Color(hex: "#007aff").opacity(0.10)
                        : Color(hex: "#86868b").opacity(0.10))
                    .frame(width: 24, height: 24)
                Image(systemName: item.sfSymbolName)
                    .font(.system(size: 12))
                    .foregroundColor(item.isDirectory
                        ? Color(hex: "#007aff")
                        : Color(hex: "#86868b"))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#1d1d1f"))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    Text(item.formattedSize)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#86868b"))
                    Text(item.formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#86868b"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 目录箭头指示器
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#86868b"))
                    .opacity(isHovering ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected
                    ? Color(hex: "#007aff").opacity(0.10)
                    : (isHovering ? Color.black.opacity(0.05) : Color.clear))
        )
        .overlay(
            isSelected
                ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(hex: "#007aff").opacity(0.30), lineWidth: 1)
                : nil
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - 远程文件行视图

/// 远程文件/目录行（双行布局：文件名 + 大小+时间）
struct RemoteFileRowView: View {

    let item: SFTPFileItem
    let isSelected: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // 图标容器
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(item.fileType.isDirectory
                        ? Color(hex: "#34c759").opacity(0.10)
                        : Color(hex: "#86868b").opacity(0.10))
                    .frame(width: 24, height: 24)
                Image(systemName: item.fileType.sfSymbolName)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#1d1d1f"))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    Text(item.formattedSize)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#86868b"))
                    Text(item.formattedDate)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#86868b"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 目录箭头指示器
            if item.fileType.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#86868b"))
                    .opacity(isHovering ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected
                    ? Color(hex: "#34c759").opacity(0.10)
                    : (isHovering ? Color.black.opacity(0.05) : Color.clear))
        )
        .overlay(
            isSelected
                ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(hex: "#34c759").opacity(0.30), lineWidth: 1)
                : nil
        )
        .onHover { isHovering = $0 }
        .help(item.name + "  " + item.permissionsString)
    }

    private var iconColor: Color {
        switch item.fileType {
        case .directory:    return Color(hex: "#34c759")
        case .regularFile:  return Color(hex: "#86868b")
        case .symlink:      return DesignTokens.Colors.accentSecondary
        case .other:        return Color(hex: "#86868b")
        }
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
        .background(DesignTokens.Colors.surfaceWindow)
    }
}

/// 单个传输任务行
private struct TransferItemRow: View {

    @ObservedObject var item: SFTPTransferItem
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
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
