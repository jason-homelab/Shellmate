import Foundation
import Combine

// MARK: - BaseViewModel
//
// 所有 ViewModel 的通用基类。
// 提供统一的 isLoading / errorMessage / 取消令牌袋，子类直接继承使用。
//
// 用法示例：
//   final class SFTPViewModel: BaseViewModel { ... }

@MainActor
class BaseViewModel: ObservableObject {

    // MARK: - 公开状态

    /// 是否正在执行异步操作
    @Published var isLoading: Bool = false

    /// 需要向用户呈现的错误描述（nil 表示无错误）
    @Published var errorMessage: String? = nil

    // MARK: - Combine

    /// Combine 订阅令牌袋，子类可直接使用 `store(in: &cancellables)`
    var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init() {}

    // MARK: - 辅助方法

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 以统一的 Loading 包裹执行异步任务：
    /// - 自动设置 isLoading = true / false
    /// - 捕获 LocalizedError 并写入 errorMessage
    func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
