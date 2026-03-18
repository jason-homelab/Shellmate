import CoreData

/// Core Data 持久化控制器
/// 负责管理 Core Data 栈（CloudKit 同步暂时禁用，待后续配置）
final class PersistenceController {

    // MARK: - 单例

    static let shared = PersistenceController()

    /// 预览用的内存存储控制器（用于 SwiftUI Preview）
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // 创建示例数据
        let group = CDSessionGroup(context: viewContext)
        group.id = UUID()
        group.name = "开发服务器"
        group.colorHex = "#4A90D9"
        group.sortOrder = 0
        group.isExpanded = true
        group.modifiedAt = Date()

        for i in 0..<5 {
            let session = CDSession(context: viewContext)
            session.id = UUID()
            session.name = "服务器 \(i + 1)"
            session.host = "192.168.1.\(100 + i)"
            session.port = 22
            session.username = "root"
            session.authMethodRaw = 0
            session.keepAliveInterval = 60
            session.autoReconnect = true
            session.encoding = "UTF-8"
            session.sortOrder = Int32(i)
            session.createdAt = Date()
            session.modifiedAt = Date()
            session.isSoftDeleted = false
            session.group = group
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("创建预览数据失败: \(nsError), \(nsError.userInfo)")
        }

        return controller
    }()

    // MARK: - 属性

    /// NSPersistentContainer（暂时不使用 CloudKit）
    let container: NSPersistentContainer

    /// 主线程视图上下文
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - 初始化

    /// 初始化持久化控制器
    /// - Parameter inMemory: 是否使用内存存储（用于预览和测试）
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ShellMate")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // 生产环境中应当优雅处理错误，而非 fatalError
                fatalError("持久化存储加载失败: \(error), \(error.userInfo)")
            }
        }

        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - 保存方法

    /// 保存视图上下文的更改
    func save() {
        let context = container.viewContext

        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("保存上下文失败: \(nsError), \(nsError.userInfo)")
        }
    }

    /// 在后台上下文中执行操作
    /// - Parameter block: 要执行的操作闭包
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }

    /// 创建新的后台上下文
    /// - Returns: 新的后台上下文
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
