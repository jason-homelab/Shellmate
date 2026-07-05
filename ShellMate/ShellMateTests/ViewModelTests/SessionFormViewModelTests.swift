import XCTest
@testable import ShellMate

/// SessionFormViewModel 单元测试
/// 覆盖新建连接的三个回归修复：
///  - 默认协议为 SSH（含陈旧/非法存储值兜底）
///  - 会话名称留空时自动使用主机名（canSave 不再强制 name）
///  - 私钥认证可正常保存
@MainActor
final class SessionFormViewModelTests: XCTestCase {

    // MARK: - Bug 1：新建默认 SSH

    func test_newSession_defaultProtocol_SSH() {
        let vm = SessionFormViewModel()
        vm.configure(defaultProtocol: "SSH")
        XCTAssertEqual(vm.connectionProtocol, "SSH")
    }

    func test_newSession_invalidStoredProtocol_fallsBackToSSH() {
        let vm = SessionFormViewModel()
        vm.configure(defaultProtocol: "")            // key 存在但为空
        XCTAssertEqual(vm.connectionProtocol, "SSH", "空的默认协议应回退到 SSH")

        let vm2 = SessionFormViewModel()
        vm2.configure(defaultProtocol: "NotAProtocol")
        XCTAssertEqual(vm2.connectionProtocol, "SSH", "非法默认协议应回退到 SSH")
    }

    func test_configure_validNonSSHProtocol_respected() {
        let vm = SessionFormViewModel()
        vm.configure(defaultProtocol: "Telnet")
        XCTAssertEqual(vm.connectionProtocol, "Telnet", "合法的非 SSH 默认协议应被采用")
    }

    // MARK: - Bug 2：名称留空自动用主机名 + canSave 不强制 name

    func test_canSave_blankName_withHostAndUser_isTrue() {
        let vm = SessionFormViewModel()
        vm.configure(defaultProtocol: "SSH")
        vm.host = "10.0.0.5"
        vm.username = "root"
        vm.port = "22"
        vm.name = ""   // 留空
        XCTAssertTrue(vm.canSave, "名称留空但主机/用户/端口齐全时应可保存")
    }

    func test_save_blankName_derivesFromHost() {
        var saved: Session?
        let vm = SessionFormViewModel(onSave: { saved = $0 })
        vm.configure(defaultProtocol: "SSH")
        vm.host = "example.com"
        vm.username = "root"
        vm.port = "22"
        vm.name = ""
        vm.saveCredential = false
        vm.save()
        XCTAssertEqual(saved?.name, "example.com", "名称留空应自动取主机名")
        XCTAssertEqual(saved?.connectionType, .ssh)
        XCTAssertTrue(vm.validationErrors.isEmpty, "名称留空不应再产生校验错误")
    }

    func test_save_explicitName_isKept() {
        var saved: Session?
        let vm = SessionFormViewModel(onSave: { saved = $0 })
        vm.configure(defaultProtocol: "SSH")
        vm.host = "example.com"
        vm.username = "root"
        vm.port = "22"
        vm.name = "  My Server  "
        vm.saveCredential = false
        vm.save()
        XCTAssertEqual(saved?.name, "My Server", "显式名称应保留（去首尾空格）")
    }

    // MARK: - Bug 2 直接场景：私钥认证可保存

    func test_save_privateKeyAuth_persistsAuthAndPath() {
        var saved: Session?
        let vm = SessionFormViewModel(onSave: { saved = $0 })
        vm.configure(defaultProtocol: "SSH")
        vm.host = "example.com"
        vm.username = "root"
        vm.port = "22"
        vm.authMethod = .privateKey
        vm.privateKeyPath = "/Users/x/.ssh/id_rsa"
        vm.saveCredential = false   // 避免测试触碰 Keychain
        vm.save()
        XCTAssertNotNil(saved, "私钥认证也应能保存")
        XCTAssertEqual(saved?.authMethod, .privateKey)
        XCTAssertEqual(saved?.privateKeyPath, "/Users/x/.ssh/id_rsa")
    }
}
