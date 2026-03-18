import Foundation
import CoreData

/// 会话仓库协议
/// 定义会话数据的 CRUD 操作接口
protocol SessionRepositoryProtocol {
    func fetchAll() async throws -> [Session]
    func fetch(by id: UUID) async throws -> Session?
    func save(_ session: Session) async throws
    func delete(_ session: Session) async throws
    func search(query: String) async throws -> [Session]
    func move(session: Session, to groupId: UUID?) async throws
    func updateSortOrder(sessions: [Session]) async throws
}

/// 会话仓库实现
/// 负责会话数据的持久化操作
@MainActor
final class SessionRepository: SessionRepositoryProtocol {

    // MARK: - 属性

    private let persistenceController: PersistenceController

    // MARK: - 初始化

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - 获取方法

    /// 获取所有会话（不包括软删除的）
    func fetchAll() async throws -> [Session] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        request.predicate = NSPredicate(format: "isSoftDeleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDSession.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CDSession.name, ascending: true)
        ]

        let entities = try context.fetch(request)
        return entities.map { Session(from: $0) }
    }

    /// 根据 ID 获取会话
    func fetch(by id: UUID) async throws -> Session? {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND isSoftDeleted == NO", id as CVarArg)
        request.fetchLimit = 1

        let entities = try context.fetch(request)
        return entities.first.map { Session(from: $0) }
    }

    /// 根据分组 ID 获取会话列表
    func fetchByGroup(groupId: UUID?) async throws -> [Session] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()

        if let groupId = groupId {
            request.predicate = NSPredicate(
                format: "isSoftDeleted == NO AND group.id == %@",
                groupId as CVarArg
            )
        } else {
            request.predicate = NSPredicate(
                format: "isSoftDeleted == NO AND group == nil"
            )
        }

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDSession.sortOrder, ascending: true)
        ]

        let entities = try context.fetch(request)
        return entities.map { Session(from: $0) }
    }

    // MARK: - 保存方法

    /// 保存会话（新建或更新）
    func save(_ session: Session) async throws {
        let context = persistenceController.viewContext

        // 查找是否存在
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        request.fetchLimit = 1

        let entity: CDSession
        if let existing = try context.fetch(request).first {
            entity = existing
        } else {
            entity = CDSession(context: context)
            entity.createdAt = Date()
        }

        // 更新实体
        session.update(entity: entity)

        // 处理分组关系
        if let groupId = session.groupId {
            let groupRequest: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
            groupRequest.predicate = NSPredicate(format: "id == %@", groupId as CVarArg)
            groupRequest.fetchLimit = 1

            if let group = try context.fetch(groupRequest).first {
                entity.group = group
            }
        } else {
            entity.group = nil
        }

        persistenceController.save()
    }

    // MARK: - 删除方法

    /// 删除会话（软删除）
    func delete(_ session: Session) async throws {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        request.fetchLimit = 1

        if let entity = try context.fetch(request).first {
            entity.isSoftDeleted = true
            entity.modifiedAt = Date()
            persistenceController.save()
        }
    }

    /// 永久删除会话
    func permanentlyDelete(_ session: Session) async throws {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        request.fetchLimit = 1

        if let entity = try context.fetch(request).first {
            context.delete(entity)
            persistenceController.save()
        }
    }

    // MARK: - 搜索方法

    /// 搜索会话
    /// - Parameter query: 搜索关键词（匹配名称、主机、标签）
    func search(query: String) async throws -> [Session] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return try await fetchAll()
        }

        request.predicate = NSPredicate(
            format: "isSoftDeleted == NO AND (name CONTAINS[cd] %@ OR host CONTAINS[cd] %@ OR tagsJSON CONTAINS[cd] %@)",
            trimmedQuery, trimmedQuery, trimmedQuery
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDSession.sortOrder, ascending: true)
        ]

        let entities = try context.fetch(request)
        return entities.map { Session(from: $0) }
    }

    // MARK: - 移动方法

    /// 移动会话到指定分组
    func move(session: Session, to groupId: UUID?) async throws {
        var updatedSession = session
        updatedSession.groupId = groupId
        try await save(updatedSession)
    }

    // MARK: - 排序方法

    /// 批量更新排序顺序
    func updateSortOrder(sessions: [Session]) async throws {
        let context = persistenceController.viewContext

        for session in sessions {
            let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.sortOrder = session.sortOrder
                entity.modifiedAt = Date()
            }
        }

        persistenceController.save()
    }
}
