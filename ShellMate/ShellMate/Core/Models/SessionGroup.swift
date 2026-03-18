import Foundation
import SwiftUI

/// 会话分组模型
/// 对应 Core Data 实体 CDSessionGroup 的 Swift 业务模型
struct SessionGroup: Identifiable, Hashable {
    /// 唯一标识符
    let id: UUID
    /// 分组名称
    var name: String
    /// 颜色（十六进制）
    var colorHex: String
    /// 排序顺序
    var sortOrder: Int32
    /// 是否展开
    var isExpanded: Bool
    /// 修改时间
    var modifiedAt: Date
    /// 父分组 ID（用于嵌套分组）
    var parentId: UUID?
    /// 子分组 ID 列表
    var childrenIds: [UUID]

    // MARK: - 初始化

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#4A90D9",
        sortOrder: Int32 = 0,
        isExpanded: Bool = true,
        modifiedAt: Date = Date(),
        parentId: UUID? = nil,
        childrenIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isExpanded = isExpanded
        self.modifiedAt = modifiedAt
        self.parentId = parentId
        self.childrenIds = childrenIds
    }

    // MARK: - 从 Core Data 实体转换

    init(from entity: CDSessionGroup) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.colorHex = entity.colorHex ?? "#4A90D9"
        self.sortOrder = entity.sortOrder
        self.isExpanded = entity.isExpanded
        self.modifiedAt = entity.modifiedAt ?? Date()
        self.parentId = entity.parent?.id
        self.childrenIds = (entity.children as? Set<CDSessionGroup>)?
            .compactMap { $0.id } ?? []
    }

    // MARK: - 辅助方法

    /// 获取颜色
    var color: Color {
        Color(hex: colorHex)
    }

    /// 更新 Core Data 实体
    func update(entity: CDSessionGroup) {
        entity.id = id
        entity.name = name
        entity.colorHex = colorHex
        entity.sortOrder = sortOrder
        entity.isExpanded = isExpanded
        entity.modifiedAt = Date()
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SessionGroup, rhs: SessionGroup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 预览数据

extension SessionGroup {
    /// 预览用示例分组
    static let preview = SessionGroup(
        name: "开发服务器",
        colorHex: "#4A90D9"
    )

    /// 预览用示例分组列表
    static let previewList: [SessionGroup] = [
        SessionGroup(name: "开发服务器", colorHex: "#4A90D9", sortOrder: 0),
        SessionGroup(name: "测试服务器", colorHex: "#F0A500", sortOrder: 1),
        SessionGroup(name: "生产服务器", colorHex: "#F04060", sortOrder: 2),
    ]
}
