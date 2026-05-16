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

    // MARK: - 语言选择器

    @Published var showLanguagePicker: Bool = false

    // MARK: - 分屏状态

    @Published var splitLayout: SplitLayout = .none
    /// 左右/上下分屏：第二格会话 ID
    @Published var splitSessionId: Session.ID? = nil
    /// 四格分屏：格 1–3 的额外会话 ID
    @Published var gridSessionIds: [Session.ID] = []
    @Published var showSplitSessionPicker: Bool = false
}
