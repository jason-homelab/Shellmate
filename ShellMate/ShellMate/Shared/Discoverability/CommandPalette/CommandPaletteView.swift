import SwiftUI
import AppKit

// W8：⌘K 浮窗主视图
// 580pt 宽 × 最高 480pt，居中偏上 top inset 80pt，.regularMaterial 背景
// 含键盘 ↑↓ 导航、↩ 执行、ESC 关闭，无结果引导至 AI

struct CommandPaletteView: View {

    @ObservedObject var store: CommandPaletteStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        if store.isVisible {
            ZStack {
                // 半透明遮罩
                Color.black.opacity(0.20)
                    .ignoresSafeArea()
                    .onTapGesture { store.close() }
                    .transition(.opacity)

                VStack {
                    Spacer(minLength: 80)
                    palette
                        .frame(width: 580)
                        .frame(maxHeight: 480)
                    Spacer(minLength: 0)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.94).combined(with: .opacity)
                        .combined(with: .offset(y: -12)),
                    removal: .opacity
                ))
            }
            .animation(DesignTokens.Animation.spring, value: store.isVisible)
            .background(KeyboardCaptureView { event in
                handleKey(event: event)
            })
        }
    }

    // MARK: - 浮窗

    @ViewBuilder
    private var palette: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.6)
            ScrollViewReader { proxy in
                ScrollView {
                    if store.hasResults {
                        resultsSection
                    } else {
                        emptyResultsView
                    }
                }
                .onChange(of: store.selectedIndex) { newValue in
                    if let id = store.flatItems[safe: newValue]?.id {
                        withAnimation(DesignTokens.Animation.fast) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.glassBorderTop, lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .elevation(DesignTokens.Elevation.e4)
    }

    // MARK: - 搜索栏

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            AppIcon.search.image
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            TextField("在 ShellMate 中搜索…", text: $store.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .focused($searchFocused)
                .onChange(of: store.query) { _ in
                    store.selectedIndex = 0
                }

            // ⌘K / ESC 提示
            Text("⌘K")
                .font(DesignTokens.Typography.Mono.dataXS)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignTokens.Colors.glassLight)
                )

            Button(action: { store.close() }) {
                AppIcon.close.image
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 56)
        .onAppear {
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    // MARK: - 结果区

    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.groupedCapabilities, id: \.category) { group in
                sectionHeader(group.category)
                ForEach(group.items) { cap in
                    let flatIndex = store.flatItems.firstIndex(where: { $0.id == cap.id }) ?? -1
                    CommandPaletteRow(
                        capability: cap,
                        isSelected: flatIndex == store.selectedIndex
                    ) {
                        store.execute(cap)
                    }
                    .id(cap.id)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func sectionHeader(_ category: Capability.Category) -> some View {
        Text(category.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 无结果

    @ViewBuilder
    private var emptyResultsView: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            AppIcon.ai.image
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(DesignTokens.Gradients.aiIcon)
                .padding(.top, DesignTokens.Spacing.lg)

            Text("没找到匹配项")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("试试用自然语言问 AI：「\(store.query.isEmpty ? "如何…" : store.query)」")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)

            Button(action: { store.handleNoResults() }) {
                HStack(spacing: 6) {
                    AppIcon.ai.image
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DesignTokens.Gradients.aiIcon)
                    Text("询问 AI 助手")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.accentAI)
                }
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignTokens.Colors.accentAI.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(DesignTokens.Colors.accentAI.opacity(0.30), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.xs)
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 键盘事件

    private func handleKey(event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // ESC
            store.close()
            return true
        case 125: // ↓
            store.selectNext()
            return true
        case 126: // ↑
            store.selectPrevious()
            return true
        case 36, 76: // ↩ / Numpad ↩
            store.executeSelected()
            return true
        default:
            return false
        }
    }
}

// MARK: - Collection safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - 键盘捕获（AppKit 桥接，SwiftUI .onKeyPress 在 13 不可用）

private struct KeyboardCaptureView: NSViewRepresentable {

    let handler: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyCaptureNSView)?.handler = handler
    }

    final class KeyCaptureNSView: NSView {
        var handler: ((NSEvent) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    if self?.handler?(event) == true { return nil }
                    return event
                }
            } else if window == nil, let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}
