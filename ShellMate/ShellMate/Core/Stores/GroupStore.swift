import Foundation
import Combine

/// 分组状态管理器
/// 负责管理会话分组的状态和业务逻辑
@MainActor
final class GroupStore: ObservableObject {

    // MARK: - 发布属性

    /// 所有分组列表
    @Published private(set) var groups: [SessionGroup] = []

    /// 顶级分组列表（无父分组）
    @Published private(set) var topLevelGroups: [SessionGroup] = []

    /// 当前选中的分组 ID
    @Published var selectedGroupId: UUID?

    /// 正在编辑的分组（用于弹窗）
    @Published var editingGroup: SessionGroup?

    /// 是否显示新建/编辑分组弹窗
    @Published var isShowingGroupForm: Bool = false

    /// 是否正在加载
    @Published private(set) var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private let repository: GroupRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 计算属性

    /// 当前选中的分组
    var selectedGroup: SessionGroup? {
        guard let id = selectedGroupId else { return nil }
        return groups.first { $0.id == id }
    }

    // MARK: - 初始化

    init(repository: GroupRepository? = nil) {
        self.repository = repository ?? GroupRepository()
    }

    // MARK: - 加载方法

    /// 加载所有分组
    func loadGroups() async {
        isLoading = true
        errorMessage = nil

        do {
            groups = try await repository.fetchAll()
            topLevelGroups = try await repository.fetchTopLevel()
        } catch {
            errorMessage = "加载分组失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 获取分组
    func group(by id: UUID) -> SessionGroup? {
        groups.first { $0.id == id }
    }

    /// 获取子分组
    func children(of groupId: UUID) -> [SessionGroup] {
        groups.filter { $0.parentId == groupId }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - CRUD 方法

    /// 保存分组
    func saveGroup(_ group: SessionGroup) async {
        do {
            try await repository.save(group)
            await loadGroups()
        } catch {
            errorMessage = "保存分组失败: \(error.localizedDescription)"
        }
    }

    /// 删除分组
    func deleteGroup(_ group: SessionGroup) async {
        do {
            try await repository.delete(group)
            if selectedGroupId == group.id {
                selectedGroupId = nil
            }
            await loadGroups()
        } catch {
            errorMessage = "删除分组失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 展开/折叠

    /// 切换分组展开状态
    func toggleExpanded(_ group: SessionGroup) async {
        do {
            try await repository.toggleExpanded(group)
            await loadGroups()
        } catch {
            errorMessage = "切换展开状态失败: \(error.localizedDescription)"
        }
    }

    /// 设置分组展开状态
    func setExpanded(_ group: SessionGroup, isExpanded: Bool) async {
        do {
            try await repository.setExpanded(group, isExpanded: isExpanded)
            await loadGroups()
        } catch {
            errorMessage = "设置展开状态失败: \(error.localizedDescription)"
        }
    }

    /// 展开所有分组
    func expandAll() async {
        for group in groups where !group.isExpanded {
            do {
                try await repository.setExpanded(group, isExpanded: true)
            } catch {
                errorMessage = "展开所有分组失败: \(error.localizedDescription)"
                return
            }
        }
        await loadGroups()
    }

    /// 折叠所有分组
    func collapseAll() async {
        for group in groups where group.isExpanded {
            do {
                try await repository.setExpanded(group, isExpanded: false)
            } catch {
                errorMessage = "折叠所有分组失败: \(error.localizedDescription)"
                return
            }
        }
        await loadGroups()
    }

    // MARK: - 排序方法

    /// 更新分组排序
    func updateSortOrder(from source: IndexSet, to destination: Int) async {
        var sortedGroups = topLevelGroups

        sortedGroups.move(fromOffsets: source, toOffset: destination)

        for (index, var group) in sortedGroups.enumerated() {
            group.sortOrder = Int32(index)
            sortedGroups[index] = group
        }

        do {
            try await repository.updateSortOrder(groups: sortedGroups)
            await loadGroups()
        } catch {
            errorMessage = "更新排序失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 弹窗方法

    /// 显示新建分组弹窗
    func showNewGroupForm() {
        editingGroup = nil
        isShowingGroupForm = true
    }

    /// 显示编辑分组弹窗
    func showEditGroupForm(for group: SessionGroup) {
        editingGroup = group
        isShowingGroupForm = true
    }

    /// 关闭弹窗
    func dismissGroupForm() {
        isShowingGroupForm = false
        editingGroup = nil
    }
}
