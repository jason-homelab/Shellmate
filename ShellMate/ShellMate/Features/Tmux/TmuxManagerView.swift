import SwiftUI

// MARK: - O04 tmux 会话管理覆层

/// tmux 会话管理器浮动面板（覆层 O04）
/// 420×360pt 可调整大小的面板，支持附加/分离/新建/终止 tmux 会话
struct TmuxManagerView: View {

    // MARK: - 属性

    @ObservedObject var store: TmuxSessionStore
    var serverLabel: String         // "ubuntu@192.168.100.167"
    var onClose: () -> Void

    // MARK: - 私有状态

    @State private var selectedSessionName: String? = nil
    @State private var showNewSessionSheet: Bool = false
    @State private var confirmKillSession: TmuxSession? = nil
    @State private var isRefreshing: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            toolbarRow
            sessionList
            statusFooter
        }
        // 对齐规范 §10：max-w-[900px]，bg-white/95 backdrop-blur-2xl，border-[#d2d2d7]/50，rounded-2xl
        .frame(width: 420)
        .frame(minHeight: 280, maxHeight: 480)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(hex: "#d2d2d7").opacity(0.5), lineWidth: 0.75)
                }
        }
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
        .overlay {
            if showNewSessionSheet {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showNewSessionSheet = false }

                TmuxNewSessionSheet(
                    onCreate: { name, windowName in
                        store.createSession(name: name, windowName: windowName)
                        showNewSessionSheet = false
                    },
                    onCancel: { showNewSessionSheet = false }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .overlay {
            if let session = confirmKillSession {
                killConfirmationAlert(session: session)
            }
        }
        .animation(DesignTokens.Animation.spring, value: store.sessions.count)
    }

    // MARK: - 面板标题栏

    private var panelHeader: some View {
        HStack(spacing: 0) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.trailing, 8)

            Text("tmux 会话")
                .font(DesignTokens.Typography.titleSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            Text(serverLabel)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(DesignTokens.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(.trailing, 8)

            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 44)
        .background(DesignTokens.Colors.surfaceOverlay)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DesignTokens.Colors.borderFaint).frame(height: 0.5)
        }
    }

    // MARK: - 工具栏行

    private var toolbarRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 新建
            Button {
                withAnimation(DesignTokens.Animation.spring) { showNewSessionSheet = true }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                    Text("新建").font(DesignTokens.Typography.labelSmall)
                }
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.4), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help("新建 tmux 会话")

            // 附加
            Button {
                guard let name = selectedSessionName,
                      let session = store.sessions.first(where: { $0.name == name }) else { return }
                store.attach(to: session)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.to.line").font(.system(size: 10))
                    Text("附加").font(DesignTokens.Typography.labelSmall)
                }
                .foregroundColor(selectedSessionName != nil ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textDisabled)
            }
            .buttonStyle(.plain)
            .disabled(selectedSessionName == nil)
            .help("附加选中的 tmux 会话（↵）")

            // 分离
            Button { store.detach() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.line.vertical.and.arrow.right").font(.system(size: 10))
                    Text("分离").font(DesignTokens.Typography.labelSmall)
                }
                .foregroundColor(store.attachedSessionName != nil ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textDisabled)
            }
            .buttonStyle(.plain)
            .disabled(store.attachedSessionName == nil)
            .help("分离当前附加的 tmux 会话")

            tmuxToolbarDivider

            // 终止
            Button {
                if let name = selectedSessionName,
                   let session = store.sessions.first(where: { $0.name == name }) {
                    confirmKillSession = session
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash").font(.system(size: 10))
                    Text("终止").font(DesignTokens.Typography.labelSmall)
                }
                .foregroundColor(selectedSessionName != nil ? DesignTokens.Colors.statusError : DesignTokens.Colors.textDisabled)
            }
            .buttonStyle(.plain)
            .disabled(selectedSessionName == nil)
            .help("终止选中的 tmux 会话（不可撤销）")

            Spacer()

            // 刷新
            Button {
                isRefreshing = true
                store.refreshSessions()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { isRefreshing = false }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(.plain)
            .help("刷新会话列表")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 36)
        .background(DesignTokens.Colors.surfaceCard)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DesignTokens.Colors.borderFaint).frame(height: 0.5)
        }
    }

    // MARK: - 会话列表

    @ViewBuilder
    private var sessionList: some View {
        switch store.availability {
        case .unknown, .checking:
            checkingView

        case .unavailable:
            unavailableView

        case .available:
            if store.sessions.isEmpty {
                emptySessionsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.sessions) { session in
                            sessionRow(session)
                                .padding(.horizontal, DesignTokens.Spacing.xs)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: TmuxSession) -> some View {
        let isSelected = selectedSessionName == session.name
        let isCurrentlyAttached = store.attachedSessionName == session.name

        HStack(spacing: DesignTokens.Spacing.sm) {
            // 状态指示点
            GlowingStatusDot(
                color: session.isAttached ? DesignTokens.Colors.statusConnected : DesignTokens.Colors.statusConnecting,
                size: 6
            )

            // 主信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.name)
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    if isCurrentlyAttached {
                        Text("← 当前")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Colors.accentPrimary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }

                HStack(spacing: 8) {
                    Label("\(session.windowCount) 窗口", systemImage: "macwindow")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textDisabled)

                    if !session.relativeCreatedTime.isEmpty {
                        Label(session.relativeCreatedTime, systemImage: "clock")
                            .font(DesignTokens.Typography.labelSmall)
                            .foregroundColor(DesignTokens.Colors.textDisabled)
                    }

                    if !session.dimensions.isEmpty {
                        Text(session.dimensions)
                            .font(DesignTokens.Typography.codeSmall)
                            .foregroundColor(DesignTokens.Colors.textDisabled)
                    }
                }
            }

            Spacer()

            // 快捷操作按钮（选中时可见）
            if isSelected {
                if !session.isAttached {
                    Button {
                        store.attach(to: session)
                    } label: {
                        Image(systemName: "arrow.right.to.line")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                            .frame(width: 24, height: 24)
                            .background(DesignTokens.Colors.accentPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("附加此会话")
                } else {
                    Button { store.detach() } label: {
                        Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Colors.statusConnecting)
                            .frame(width: 24, height: 24)
                            .background(DesignTokens.Colors.statusConnecting.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("分离此会话")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .frame(height: 56)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected
                      ? DesignTokens.Colors.accentPrimary.opacity(0.12)
                      : Color.clear)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSessionName = session.name
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                store.attach(to: session)
            }
        )
    }

    // MARK: - 空/加载/不可用 状态

    private var checkingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
            Text("正在检测 tmux…")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("远程服务器未安装 tmux")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("可通过 `sudo apt install tmux` 或 `brew install tmux` 安装")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptySessionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 36))
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("没有活跃的 tmux 会话")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("点击「新建」创建一个会话")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - 终止确认弹窗

    @ViewBuilder
    private func killConfirmationAlert(session: TmuxSession) -> some View {
        Color.black.opacity(0.35)
            .ignoresSafeArea()
            .onTapGesture { confirmKillSession = nil }

        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(DesignTokens.Colors.statusError)

            VStack(spacing: 6) {
                Text("确认终止 tmux 会话？")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("会话「\(session.name)」及其中所有进程将被立即终止，此操作不可撤销。")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                Button("取消") { confirmKillSession = nil }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])

                Button("终止") {
                    store.kill(session: session)
                    confirmKillSession = nil
                    if selectedSessionName == session.name { selectedSessionName = nil }
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Colors.statusError)
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(width: 320)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignTokens.Colors.surfaceCard.opacity(0.9))
                }
        }
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 6)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    // MARK: - 底部状态栏

    private var statusFooter: some View {
        HStack {
            let attached = store.sessions.filter(\.isAttached).count
            let total = store.sessions.count
            Text(total == 0 ? "暂无会话" : "\(total) 个会话（\(attached) 个附加中）")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)

            Spacer()

            if case .available(let version) = store.availability {
                Text(version)
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textDisabled)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 28)
        .background(DesignTokens.Colors.surfaceToolbar)
        .overlay(alignment: .top) {
            Rectangle().fill(DesignTokens.Colors.borderFaint).frame(height: 0.5)
        }
    }

    // MARK: - 辅助

    private var tmuxToolbarDivider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.borderSecondary)
            .frame(width: 1, height: 14)
    }
}

// MARK: - 预览

#Preview("tmux 管理器 - 有会话") {
    let store = TmuxSessionStore(sessionId: UUID(), sendTarget: PreviewTmuxTarget())
    // 模拟数据
    ZStack {
        Color.black.opacity(0.85)
        TmuxManagerView(
            store: store,
            serverLabel: "ubuntu@192.168.100.167",
            onClose: {}
        )
        .padding()
    }
    .frame(width: 500, height: 480)
}

// MARK: - 预览用占位 Target

private final class PreviewTmuxTarget: TmuxSendTarget {
    func sendTmuxCommand(_ command: String) {}
}
