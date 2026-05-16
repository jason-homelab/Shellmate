import XCTest
import CoreData
@testable import ShellMate

/// CredentialVault 单元测试
/// 覆盖 AES-256-GCM 加解密、增删查全操作，使用内存 Core Data 栈
final class CredentialVaultTests: XCTestCase {

    // MARK: - 测试属性

    var vault: CredentialVault!
    var persistence: PersistenceController!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        persistence = PersistenceController(inMemory: true)
        vault = CredentialVault(persistence: persistence)
    }

    override func tearDown() async throws {
        vault = nil
        persistence = nil
        try await super.tearDown()
    }

    // MARK: - 基础增删查

    /// 保存后能正确读取
    func testSaveAndLoad() async throws {
        let sessionId = UUID()
        try await vault.save("my-secret-password", sessionId: sessionId, type: .password)
        let loaded = try await vault.load(sessionId: sessionId, type: .password)
        XCTAssertEqual(loaded, "my-secret-password")
    }

    /// 覆盖写入——同类型凭据只保留最新一条
    func testSaveOverwritesSameType() async throws {
        let sessionId = UUID()
        try await vault.save("old-password", sessionId: sessionId, type: .password)
        try await vault.save("new-password", sessionId: sessionId, type: .password)
        let loaded = try await vault.load(sessionId: sessionId, type: .password)
        XCTAssertEqual(loaded, "new-password")
    }

    /// 不同类型凭据互相独立
    func testDifferentTypesAreIndependent() async throws {
        let sessionId = UUID()
        try await vault.save("user-pass", sessionId: sessionId, type: .password)
        try await vault.save("key-passphrase", sessionId: sessionId, type: .passphrase)

        let pass = try await vault.load(sessionId: sessionId, type: .password)
        let phrase = try await vault.load(sessionId: sessionId, type: .passphrase)

        XCTAssertEqual(pass, "user-pass")
        XCTAssertEqual(phrase, "key-passphrase")
    }

    /// 读取不存在的凭据抛出 credentialNotFound
    func testLoadNonExistentThrows() async throws {
        let sessionId = UUID()
        do {
            _ = try await vault.load(sessionId: sessionId, type: .password)
            XCTFail("应抛出 credentialNotFound")
        } catch CredentialVaultError.credentialNotFound {
            // 期望的错误
        }
    }

    // MARK: - exists

    func testExistsReturnsTrueAfterSave() async throws {
        let sessionId = UUID()
        try await vault.save("secret", sessionId: sessionId, type: .password)
        let exists = await vault.exists(sessionId: sessionId, type: .password)
        XCTAssertTrue(exists)
    }

    func testExistsReturnsFalseWhenNotSaved() async {
        let exists = await vault.exists(sessionId: UUID(), type: .password)
        XCTAssertFalse(exists)
    }

    // MARK: - 删除

    func testDeleteRemovesCredential() async throws {
        let sessionId = UUID()
        try await vault.save("secret", sessionId: sessionId, type: .password)
        try await vault.delete(sessionId: sessionId, type: .password)
        let exists = await vault.exists(sessionId: sessionId, type: .password)
        XCTAssertFalse(exists)
    }

    func testDeleteDoesNotAffectOtherTypes() async throws {
        let sessionId = UUID()
        try await vault.save("pass", sessionId: sessionId, type: .password)
        try await vault.save("phrase", sessionId: sessionId, type: .passphrase)
        try await vault.delete(sessionId: sessionId, type: .password)

        let passExists = await vault.exists(sessionId: sessionId, type: .password)
        let phraseExists = await vault.exists(sessionId: sessionId, type: .passphrase)
        XCTAssertFalse(passExists)
        XCTAssertTrue(phraseExists)
    }

    func testDeleteAllRemovesAllTypes() async throws {
        let sessionId = UUID()
        try await vault.save("pass", sessionId: sessionId, type: .password)
        try await vault.save("phrase", sessionId: sessionId, type: .passphrase)
        try await vault.deleteAll(sessionId: sessionId)

        let passExists = await vault.exists(sessionId: sessionId, type: .password)
        let phraseExists = await vault.exists(sessionId: sessionId, type: .passphrase)
        XCTAssertFalse(passExists)
        XCTAssertFalse(phraseExists)
    }

    func testDeleteAllDoesNotAffectOtherSessions() async throws {
        let sessionA = UUID()
        let sessionB = UUID()
        try await vault.save("passA", sessionId: sessionA, type: .password)
        try await vault.save("passB", sessionId: sessionB, type: .password)
        try await vault.deleteAll(sessionId: sessionA)

        let aExists = await vault.exists(sessionId: sessionA, type: .password)
        let bExists = await vault.exists(sessionId: sessionB, type: .password)
        XCTAssertFalse(aExists)
        XCTAssertTrue(bExists)
    }

    // MARK: - AES-256-GCM 加密完整性

    /// 验证加密是非确定性的（每次加密产生不同 nonce/密文）
    func testEncryptionIsNondeterministic() async throws {
        let sessionId1 = UUID()
        let sessionId2 = UUID()
        try await vault.save("same-secret", sessionId: sessionId1, type: .password)
        try await vault.save("same-secret", sessionId: sessionId2, type: .password)

        // 两个会话的加密载荷不同（nonce 随机）
        let context = persistence.newBackgroundContext()
        let payloads: [Data] = try await context.perform {
            let req = CDCredential.fetchRequest()
            req.predicate = NSPredicate(
                format: "sessionId IN %@",
                [sessionId1, sessionId2] as CVarArg
            )
            return try context.fetch(req).compactMap { $0.encryptedPayload }
        }
        XCTAssertEqual(payloads.count, 2)
        XCTAssertNotEqual(payloads[0], payloads[1])
    }

    /// 解密内容能还原原始字符串（间接验证 AES-GCM 加解密正确性）
    func testRoundTripPreservesAllCharacters() async throws {
        let sessionId = UUID()
        let secrets = [
            "simple",
            "中文密码123",
            "P@ssw0rd!#$%^&*()",
            String(repeating: "a", count: 1024)
        ]
        for secret in secrets {
            try await vault.save(secret, sessionId: sessionId, type: .password)
            let loaded = try await vault.load(sessionId: sessionId, type: .password)
            XCTAssertEqual(loaded, secret, "字符串 '\(secret.prefix(20))' 加解密后不一致")
        }
    }
}
