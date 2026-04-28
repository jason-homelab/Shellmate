import SwiftUI
import AppKit
import Combine

// MARK: - SFTP 面板 ViewModel

/// 封装 SFTP 双栏面板的所有业务逻辑：本地/远程目录浏览、文件操作、传输队列驱动、拖拽上传。
@MainActor
final class SFTPPanelViewModel: BaseViewModel {

    // MARK: - 依赖

    private let sftpSession: SFTPSession
    let transferQueue: SFTPTransferQueue
    let sessionName: String

    // MARK: - 本地文件状态

    @Published var localPath: String = NSHomeDirectory()
    @Published var localItems: [LocalFileItem] = []
    @Published var selectedLocalId: UUID?

    // MARK: - 远程文件状态

    @Published var remotePath: String = "/"
    @Published var remoteItems: [SFTPFileItem] = []
    @Published var isRemoteLoading: Bool = false
    @Published var remoteError: String?
    @Published var selectedRemoteId: UUID?

    // MARK: - 拖放

    @Published var isDragTargeted: Bool = false

    // MARK: - 传输面板

    @Published var showTransferPanel: Bool = false

    // MARK: - 弹窗状态

    @Published var showNewLocalFolderDialog: Bool = false
    @Published var newLocalFolderName: String = ""
    @Published var showNewRemoteFolderDialog: Bool = false
    @Published var newRemoteFolderName: String = ""
    @Published var showRemoteRenameDialog: Bool = false
    @Published var renameTarget: SFTPFileItem?
    @Published var renameName: String = ""
    @Published var showPermissionsDialog: Bool = false
    @Published var permissionsTarget: SFTPFileItem?
    @Published var permissionsInput: String = ""

    // MARK: - 初始化

    init(sftpSession: SFTPSession, transferQueue: SFTPTransferQueue, sessionName: String = "") {
        self.sftpSession = sftpSession
        self.transferQueue = transferQueue
        self.sessionName = sessionName
        super.init()

        // 将 transferQueue 的 objectWillChange 传播给本 ViewModel，触发视图刷新
        transferQueue.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - 计算属性

    var canUpload: Bool {
        guard let id = selectedLocalId,
              let item = localItems.first(where: { $0.id == id }) else { return false }
        return !item.isDirectory
    }

    var canDownload: Bool {
        guard let id = selectedRemoteId,
              let item = remoteItems.first(where: { $0.id == id }) else { return false }
        return item.fileType == .regularFile
    }

    var localTotalFileCount: Int {
        localItems.filter { !$0.isDirectory }.count
    }

    var localSelectedFileCount: Int {
        guard let id = selectedLocalId,
              let item = localItems.first(where: { $0.id == id }),
              !item.isDirectory else { return 0 }
        return 1
    }

    var remoteTotalFileCount: Int {
        remoteItems.filter { $0.fileType == .regularFile }.count
    }

    var remoteSelectedFileCount: Int {
        guard let id = selectedRemoteId,
              let item = remoteItems.first(where: { $0.id == id }),
              item.fileType == .regularFile else { return 0 }
        return 1
    }

    // MARK: - 初始加载

    func onAppear() {
        loadLocalDirectory(path: localPath)
        loadRemoteDirectory(path: remotePath)
    }

    /// PWD 同步：终端 cd 后自动导航远程面板
    func syncRemoteDirectoryIfNeeded(_ newDir: String?) {
        guard let dir = newDir, !dir.isEmpty, dir != remotePath else { return }
        remotePath = dir
        loadRemoteDirectory(path: dir)
    }

    // MARK: - 本地文件操作

    func loadLocalDirectory(path: String) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return }

        var items: [LocalFileItem] = []

        if path != "/" {
            let parent = (path as NSString).deletingLastPathComponent
            items.append(LocalFileItem(name: "..", path: parent, isDirectory: true))
        }

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

    func navigateLocalTo(path: String) {
        loadLocalDirectory(path: path)
    }

    func deleteSelectedLocal() {
        guard let id = selectedLocalId,
              let item = localItems.first(where: { $0.id == id }) else { return }
        deleteLocalItem(item)
    }

    func deleteLocalItem(_ item: LocalFileItem) {
        guard item.name != ".." else { return }
        try? FileManager.default.removeItem(atPath: item.path)
        loadLocalDirectory(path: localPath)
    }

    func createLocalFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newPath = localPath.hasSuffix("/") ? "\(localPath)\(trimmed)" : "\(localPath)/\(trimmed)"
        try? FileManager.default.createDirectory(atPath: newPath, withIntermediateDirectories: false)
        loadLocalDirectory(path: localPath)
        newLocalFolderName = ""
    }

    func uploadLocalItem(_ item: LocalFileItem) {
        guard !item.isDirectory else { return }
        let dest = remotePath.hasSuffix("/")
            ? "\(remotePath)\(item.name)"
            : "\(remotePath)/\(item.name)"
        transferQueue.enqueueUpload(localPath: item.path, remotePath: dest)
        showTransferPanel = true
    }

    // MARK: - 远程文件操作

    func loadRemoteDirectory(path: String) {
        isRemoteLoading = true
        remoteError = nil
        selectedRemoteId = nil

        Task {
            do {
                let result = try await sftpSession.listDirectory(path: path)
                await MainActor.run {
                    var items = result
                    if path != "/" {
                        let parent = (path as NSString).deletingLastPathComponent
                        let parentItem = SFTPFileItem(name: "..", path: parent, fileType: .directory)
                        items.insert(parentItem, at: 0)
                    }
                    self.remoteItems = items
                    self.remotePath = path
                    self.isRemoteLoading = false
                }
            } catch {
                await MainActor.run {
                    self.remoteError = error.localizedDescription
                    self.isRemoteLoading = false
                }
            }
        }
    }

    func navigateRemoteTo(path: String) {
        let normalized = sanitizeRemotePath(path)
        guard !normalized.isEmpty, normalized != remotePath else { return }
        loadRemoteDirectory(path: normalized)
    }

    func handleRemoteDoubleClick(item: SFTPFileItem) {
        if item.fileType.isDirectory {
            navigateRemoteTo(path: item.path)
        } else {
            downloadRemoteItem(item)
        }
    }

    func deleteSelectedRemote() {
        guard let id = selectedRemoteId,
              let item = remoteItems.first(where: { $0.id == id }) else { return }
        deleteRemoteItem(item)
    }

    func deleteRemoteItem(_ item: SFTPFileItem) {
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
                    self.remoteError = "删除失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func downloadRemoteItem(_ item: SFTPFileItem) {
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

    func performRemoteRename(item: SFTPFileItem, newName: String) {
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
                    self.remoteError = "重命名失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func performCreateRemoteFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newPath = remotePath.hasSuffix("/") ? "\(remotePath)\(trimmed)" : "\(remotePath)/\(trimmed)"
        Task {
            do {
                try await sftpSession.createDirectory(path: newPath)
                loadRemoteDirectory(path: remotePath)
            } catch {
                await MainActor.run {
                    self.remoteError = "创建文件夹失败：\(error.localizedDescription)"
                }
            }
        }
        newRemoteFolderName = ""
    }

    func performSetPermissions(item: SFTPFileItem, modeString: String) {
        guard let mode = UInt32(modeString, radix: 8) else { return }
        Task {
            do {
                try await sftpSession.setPermissions(path: item.path, mode: mode)
                loadRemoteDirectory(path: remotePath)
            } catch {
                await MainActor.run {
                    self.remoteError = "修改权限失败：\(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 顶栏操作

    func performUpload() {
        guard canUpload,
              let id = selectedLocalId,
              let item = localItems.first(where: { $0.id == id }) else { return }
        uploadLocalItem(item)
    }

    func performDownload() {
        guard canDownload,
              let id = selectedRemoteId,
              let item = remoteItems.first(where: { $0.id == id }) else { return }
        downloadRemoteItem(item)
    }

    func handleDropProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, _ in
                guard let self,
                      let data = item as? Data,
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

    func sanitizeRemotePath(_ rawPath: String) -> String {
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
