import Foundation
import Combine

// MARK: - SFTP 传输队列

/// SFTP 传输队列
/// 管理并发传输任务，最大并发数为 3（PRD 10.4）
@MainActor
final class SFTPTransferQueue: ObservableObject {

    // MARK: - 属性

    /// 所有传输条目（包括已完成的历史记录）
    @Published private(set) var items: [SFTPTransferItem] = []

    /// 最大并发传输数
    let maxConcurrent: Int

    /// 所属 SFTP 会话
    private weak var sftpSession: SFTPSession?

    /// 活跃任务映射（id → Task）
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - 初始化

    init(sftpSession: SFTPSession, maxConcurrent: Int = AppConstants.sftpMaxConcurrentTransfers) {
        self.sftpSession = sftpSession
        self.maxConcurrent = maxConcurrent
    }

    // MARK: - 队列管理

    /// 添加下载任务
    @discardableResult
    func enqueueDownload(
        remotePath: String,
        localPath: String,
        fileSize: UInt64 = 0,
        resume: Bool = false
    ) -> SFTPTransferItem {
        let item = SFTPTransferItem(
            localPath: localPath,
            remotePath: remotePath,
            direction: .download,
            totalBytes: fileSize
        )
        items.append(item)
        processQueue()
        return item
    }

    /// 添加上传任务
    @discardableResult
    func enqueueUpload(
        localPath: String,
        remotePath: String,
        resume: Bool = false
    ) -> SFTPTransferItem {
        let localSize = (try? FileManager.default.attributesOfItem(atPath: localPath)[.size] as? UInt64) ?? 0
        let item = SFTPTransferItem(
            localPath: localPath,
            remotePath: remotePath,
            direction: .upload,
            totalBytes: localSize
        )
        items.append(item)
        processQueue()
        return item
    }

    /// 取消指定传输任务
    func cancel(_ item: SFTPTransferItem) {
        item.isCancelled = true
        activeTasks[item.id]?.cancel()
        activeTasks.removeValue(forKey: item.id)
        if item.state == .pending || item.state == .inProgress {
            item.state = .cancelled
        }
        processQueue()
    }

    /// 取消所有任务
    func cancelAll() {
        for item in items where !item.state.isTerminal {
            item.isCancelled = true
            activeTasks[item.id]?.cancel()
        }
        activeTasks.removeAll()
        processQueue()
    }

    /// 清除已完成/已取消/已失败的历史记录
    func clearCompleted() {
        items.removeAll { $0.state.isTerminal }
    }

    // MARK: - 计算属性

    /// 活跃传输数
    var activeCount: Int { activeTasks.count }

    /// 等待中的条目
    var pendingItems: [SFTPTransferItem] { items.filter { $0.state == .pending } }

    /// 是否有活跃传输
    var hasActiveTransfers: Bool { !activeTasks.isEmpty }

    // MARK: - 私有：调度逻辑

    private func processQueue() {
        guard let session = sftpSession else { return }

        // activeTasks 是权威来源：任务完成时会自行移除
        // 只需计算剩余空位，然后启动等待中的任务
        let pending = items.filter { $0.state == .pending }
        let slotsAvailable = maxConcurrent - activeTasks.count

        guard slotsAvailable > 0 else { return }

        for item in pending.prefix(slotsAvailable) {
            startTransfer(item: item, session: session)
        }
    }

    private func startTransfer(item: SFTPTransferItem, session: SFTPSession) {
        let task = Task {
            do {
                switch item.direction {
                case .download:
                    try await session.downloadFile(
                        remotePath: item.remotePath,
                        localPath: item.localPath,
                        transferItem: item,
                        resume: false
                    )
                case .upload:
                    try await session.uploadFile(
                        localPath: item.localPath,
                        remotePath: item.remotePath,
                        transferItem: item,
                        resume: false
                    )
                }
            } catch SSHError.cancelled {
                // 已由 cancel() 设置状态
            } catch {
                await MainActor.run {
                    item.state = .failed(error.localizedDescription)
                }
            }

            // 任务完成后，尝试启动下一个排队的任务
            await MainActor.run { [weak self] in
                self?.activeTasks.removeValue(forKey: item.id)
                self?.processQueue()
            }
        }

        activeTasks[item.id] = task
    }
}
