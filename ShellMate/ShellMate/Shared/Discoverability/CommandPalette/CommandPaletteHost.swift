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
            .onReceive(NotificationCenter.default.publisher(for: .toggleCommandPalette)) { _ in
                // W3 CapabilityBootstrap 注册的 system.command_palette Capability
                // 会发送此 Notification（CapabilityBootstrap 内的 action）
                store.toggle()
            }
    }
}
