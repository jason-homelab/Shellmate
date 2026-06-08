import SwiftUI

// W8：命令面板的全局宿主
// 与 ToastHost / BannerHost 类似的注入模式：ContentView ZStack 顶层

struct CommandPaletteHost: View {

    @StateObject private var store = CommandPaletteStore()

    var body: some View {
        CommandPaletteView(store: store)
            .onReceive(NotificationCenter.default.publisher(for: .toggleCommandPaletteRequested)) { _ in
                store.toggle()
            }
            // 自评 P0#3：自指 system.command_palette capability 已移除，
            // 因此不再需要订阅 .toggleCommandPalette
    }
}
