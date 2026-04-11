import Foundation

extension Collection {
    /// 安全下标：越界时返回 nil，而非 crash
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
