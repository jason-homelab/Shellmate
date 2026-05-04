import Foundation
@testable import ShellMate

// MARK: - MockSFTPSession
//
// SFTPSession 不执行真实连接（init 为空），直接 typealias 供测试复用。
// 无需继承，避免 final class 限制。

typealias MockSFTPSession = SFTPSession
