import SwiftUI

/// ContentView 的面板/分屏状态 ViewModel
/// 将所有面板可见性和分屏布局状态从 ContentView 中提取，使主视图专注于布局路由。
@MainActor
final class ContentViewModel: ObservableObject {

    // MARK: - 面板与对话框

    @Published var showScriptPanel: Bool = false
    @Published var showSharePopover: Bool = false
    @Published var showSSHConfigImport: Bool = false
    @Published var showRecordingDialog: Bool = false
    @Published var showLogPanel: Bool = false
    @Published var showImportExportDialog: Bool = false
    @Published var showSettingsPanel: Bool = false

    // MARK: - 工具面板（ContentView 级遮罩，同 Settings 样式）

    @Published var showTunnelPanel: Bool = false
    @Published var showTmuxPanel: Bool = false
    @Published var showQuickCommandPanel: Bool = false
    @Published var showSyncInputPanel: Bool = false
    /// 发起同步输入的会话 ID（SyncInputConfirmView 需要）
    var syncInputSessionId: UUID? = nil

    // MARK: - 语言选择器

    @Published var showLanguagePicker: Bool = false

    // MARK: - 分屏状态

    @Published var splitLayout: SplitLayout = .none
    /// 左右/上下分屏：第二格会话 ID
    @Published var splitSessionId: Session.ID? = nil
    /// 四格分屏：格 1–3 的额外会话 ID
    @Published var gridSessionIds: [Session.ID] = []
    @Published var showSplitSessionPicker: Bool = false

    // MARK: - 互斥面板控制

    /// 关闭所有 sheet 面板（在打开设置浮动面板前调用，防止 sheet + overlay 叠加）
    func closeAllSheets() {
        showScriptPanel = false
        showSSHConfigImport = false
        showRecordingDialog = false
        showLogPanel = false
        showImportExportDialog = false
    }

    /// 关闭所有工具面板（切换 Tab 时调用，避免跨会话数据错乱）
    func closeToolPanels() {
        showTunnelPanel = false
        showTmuxPanel = false
        showQuickCommandPanel = false
        showSyncInputPanel = false
    }

    /// 打开设置浮动面板，同时关闭所有 sheet 防止层叠冲突
    func openSettingsPanel() {
        closeAllSheets()
        withAnimation(.easeInOut(duration: 0.2)) { showSettingsPanel = true }
    }

    /// 打开某个 sheet 面板，同时关闭设置浮动面板防止层叠冲突
    func openSheet(_ open: () -> Void) {
        showSettingsPanel = false
        open()
    }
}
