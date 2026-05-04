import XCTest
@testable import ShellMate

/// SFTPPanelViewModel 单元测试
/// 覆盖路径规范化、计算属性及弹窗状态流转
@MainActor
final class SFTPPanelViewModelTests: XCTestCase {

    // MARK: - 辅助：创建轻量级 ViewModel（不依赖真实 SFTP 连接）

    /// 使用 MockSFTPSession 避免真实网络 IO
    private func makeVM() -> SFTPPanelViewModel {
        let session = MockSFTPSession()
        let queue   = SFTPTransferQueue(sftpSession: session)
        return SFTPPanelViewModel(sftpSession: session, transferQueue: queue, sessionName: "测试服务器")
    }

    // MARK: - 初始状态

    func testInitialState_localPathIsHome() {
        let vm = makeVM()
        XCTAssertEqual(vm.localPath, NSHomeDirectory())
    }

    func testInitialState_remotePathIsRoot() {
        let vm = makeVM()
        XCTAssertEqual(vm.remotePath, "/")
    }

    func testInitialState_noSelection() {
        let vm = makeVM()
        XCTAssertNil(vm.selectedLocalId)
        XCTAssertNil(vm.selectedRemoteId)
    }

    func testInitialState_dialogsHidden() {
        let vm = makeVM()
        XCTAssertFalse(vm.showNewLocalFolderDialog)
        XCTAssertFalse(vm.showNewRemoteFolderDialog)
        XCTAssertFalse(vm.showRemoteRenameDialog)
        XCTAssertFalse(vm.showPermissionsDialog)
        XCTAssertFalse(vm.showTransferPanel)
    }

    func testInitialState_sessionNameStored() {
        let vm = makeVM()
        XCTAssertEqual(vm.sessionName, "测试服务器")
    }

    // MARK: - sanitizeRemotePath

    func testSanitize_absolutePath_unchanged() {
        let vm = makeVM()
        XCTAssertEqual(vm.sanitizeRemotePath("/home/ubuntu"), "/home/ubuntu")
    }

    func testSanitize_dotDot_removesSegment() {
        let vm = makeVM()
        XCTAssertEqual(vm.sanitizeRemotePath("/home/ubuntu/.."), "/home")
    }

    func testSanitize_singleDot_ignored() {
        let vm = makeVM()
        XCTAssertEqual(vm.sanitizeRemotePath("/home/./ubuntu"), "/home/ubuntu")
    }

    func testSanitize_emptyPath_returnsRoot() {
        let vm = makeVM()
        XCTAssertEqual(vm.sanitizeRemotePath(""), "/")
    }

    func testSanitize_rootDotDot_staysRoot() {
        let vm = makeVM()
        XCTAssertEqual(vm.sanitizeRemotePath("/.."), "/")
    }

    func testSanitize_multipleDotDot_collapses() {
        let vm = makeVM()
        XCTAssertEqual(vm.sanitizeRemotePath("/a/b/c/../../d"), "/a/d")
    }

    func testSanitize_trailingSlash_normalized() {
        let vm = makeVM()
        XCTAssertEqual(vm.sanitizeRemotePath("/home/ubuntu/"), "/home/ubuntu")
    }

    // MARK: - canUpload / canDownload（无选中时均为 false）

    func testCanUpload_noSelection_returnsFalse() {
        let vm = makeVM()
        XCTAssertFalse(vm.canUpload)
    }

    func testCanDownload_noSelection_returnsFalse() {
        let vm = makeVM()
        XCTAssertFalse(vm.canDownload)
    }

    // MARK: - 文件计数（初始为 0）

    func testLocalTotalFileCount_empty_isZero() {
        let vm = makeVM()
        XCTAssertEqual(vm.localTotalFileCount, 0)
    }

    func testRemoteTotalFileCount_empty_isZero() {
        let vm = makeVM()
        XCTAssertEqual(vm.remoteTotalFileCount, 0)
    }

    func testLocalSelectedFileCount_noSelection_isZero() {
        let vm = makeVM()
        XCTAssertEqual(vm.localSelectedFileCount, 0)
    }

    func testRemoteSelectedFileCount_noSelection_isZero() {
        let vm = makeVM()
        XCTAssertEqual(vm.remoteSelectedFileCount, 0)
    }

    // MARK: - 弹窗状态切换

    func testShowNewLocalFolderDialog_canBeToggled() {
        let vm = makeVM()
        vm.showNewLocalFolderDialog = true
        XCTAssertTrue(vm.showNewLocalFolderDialog)
        vm.showNewLocalFolderDialog = false
        XCTAssertFalse(vm.showNewLocalFolderDialog)
    }

    func testShowNewRemoteFolderDialog_canBeToggled() {
        let vm = makeVM()
        vm.showNewRemoteFolderDialog = true
        XCTAssertTrue(vm.showNewRemoteFolderDialog)
        vm.showNewRemoteFolderDialog = false
        XCTAssertFalse(vm.showNewRemoteFolderDialog)
    }

    func testShowTransferPanel_canBeToggled() {
        let vm = makeVM()
        vm.showTransferPanel = true
        XCTAssertTrue(vm.showTransferPanel)
    }

    // MARK: - syncRemoteDirectoryIfNeeded

    func testSync_updatesRemotePath_whenDifferent() {
        let vm = makeVM()
        vm.syncRemoteDirectoryIfNeeded("/home/ubuntu")
        XCTAssertEqual(vm.remotePath, "/home/ubuntu")
    }

    func testSync_noOp_whenSamePath() {
        let vm = makeVM()
        vm.syncRemoteDirectoryIfNeeded("/")
        XCTAssertEqual(vm.remotePath, "/")
    }

    func testSync_noOp_whenNil() {
        let vm = makeVM()
        vm.syncRemoteDirectoryIfNeeded(nil)
        XCTAssertEqual(vm.remotePath, "/")
    }

    func testSync_noOp_whenEmpty() {
        let vm = makeVM()
        vm.syncRemoteDirectoryIfNeeded("")
        XCTAssertEqual(vm.remotePath, "/")
    }

    // MARK: - createLocalFolder（空名不执行）

    func testCreateLocalFolder_emptyName_doesNotCrash() {
        let vm = makeVM()
        vm.createLocalFolder(name: "")
        vm.createLocalFolder(name: "   ")
        // 无 crash 即通过
    }
}
