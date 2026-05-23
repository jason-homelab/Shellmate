import SwiftUI

// MARK: - O04 tmux 会话管理覆层

// MARK: - Tab 枚举

private enum TmuxTab: String, CaseIterable {
    case sessions     = "Sessions"
    case windows      = "Windows"
    case quickActions = "Quick Actions"
}

/// tmux 会话管理器浮动面板（覆层 O04）
/// 对齐 Figma-Spec-v2 §10：三 Tab 结构（Sessions / Windows / Quick Actions），640pt 宽
struct TmuxManagerView: View {

    // MARK: - 属性

    @ObservedObject var store: TmuxSessionStore
    var serverLabel: String
    var onClose: () -> Void

    // MARK: - 私有状态

    @State private var activeTab: TmuxTab = .sessions
    @State private var selectedSessionName: String? = nil
    @State private var showNewSessionSheet: Bool = false
    @State private var confirmKillSession: TmuxSession? = nil
    @State private var isRefreshing: Bool = false
    @State private var windowsSessionName: String? = nil

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            // 24.4：版本过旧警告横幅
            if store.isVersionTooOld {
                versionWarningBanner
            }
            tabSelectorRow
            tabContentView
            statusFooter
        }
        // Figma 18:2: 880px white card, rounded-2xl, shadow-[0px_8px_20px_0px_rgba(0,0,0,0.18)]
        .frame(width: 880)
        .frame(minHeight: 420, maxHeight: 660)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
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
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.accentSecondary)
                .padding(.trailing, DesignTokens.Spacing.sm)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text("tmux 会话管理器")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("管理并监控服务器上的 tmux 会话")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Text(serverLabel)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.nano)
                .background(DesignTokens.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXXSmall, style: .continuous))
                .padding(.trailing, DesignTokens.Spacing.sm)

            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 52)
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(Color.white.opacity(0.60))
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(DesignTokens.Colors.borderFaint).frame(height: 0.5)
        }
    }

    // MARK: - 版本警告横幅（24.4）

    private var versionWarningBanner: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.statusConnecting)
            Text("当前服务器的 tmux 版本低于 2.0，部分功能可能不兼容，建议升级至 tmux 2.0 或更高版本")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.statusConnecting.opacity(0.10))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Tab 选择器

    private var tabSelectorRow: some View {
        HStack(spacing: DesignTokens.Spacing.xxxs) {
            ForEach(TmuxTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { activeTab = tab }
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: activeTab == tab ? .medium : .regular))
                        .foregroundColor(activeTab == tab
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(activeTab == tab ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .shadow(color: activeTab == tab ? Color.black.opacity(0.08) : Color.clear, radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.xxs)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    // MARK: - Tab 内容区

    @ViewBuilder
    private var tabContentView: some View {
        switch activeTab {
        case .sessions:
            sessionsTabContent
        case .windows:
            windowsTabContent
        case .quickActions:
            quickActionsTabContent
        }
    }

    // MARK: - Sessions Tab

    private var sessionsTabContent: some View {
        VStack(spacing: 0) {
            // 操作行
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    isRefreshing = true
                    store.refreshSessions()
                    Task { try? await Task.sleep(nanoseconds: 1_000_000_000); isRefreshing = false }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.nano) {
                        Image(systemName: "arrow.clockwise")
                            .font(DesignTokens.Typography.captionMedium)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        Text("刷新")
                            .font(DesignTokens.Typography.captionLarge)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                let total = store.sessions.count
                Text(total == 0 ? "暂无会话" : "\(total) 个会话")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textDisabled)

                Spacer()

                Button {
                    withAnimation(DesignTokens.Animation.spring) { showNewSessionSheet = true }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Image(systemName: "plus").font(DesignTokens.Typography.captionMedium)
                        Text("新建会话").font(DesignTokens.Typography.labelSmall)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(DesignTokens.Colors.accentSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(height: 40)
            .background {
                Rectangle().fill(.thinMaterial)
                Rectangle().fill(Color.white.opacity(0.60))
            }
            .overlay(Divider(), alignment: .bottom)

            // 会话卡片列表
            sessionListContent
        }
    }

    @ViewBuilder
    private var sessionListContent: some View {
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
                    LazyVStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(store.sessions) { session in
                            sessionCard(session)
                                .padding(.horizontal, DesignTokens.Spacing.md)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionCard(_ session: TmuxSession) -> some View {
        let isAttached = session.isAttached
        let isCurrentlyAttached = store.attachedSessionName == session.name

        HStack(spacing: DesignTokens.Spacing.sm) {
            // 主信息
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(session.name)
                        .font(DesignTokens.Typography.codeMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    if isAttached {
                        Text("已附加")
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xxxs)
                            .background(DesignTokens.Colors.accentSecondary)
                            .clipShape(Capsule())
                    }

                    if isCurrentlyAttached {
                        Text("当前")
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xxxs)
                            .background(DesignTokens.Colors.accentPrimary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMicro, style: .continuous))
                    }
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Label("\(session.windowCount) 个窗口", systemImage: "macwindow")
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

            // 操作按钮
            HStack(spacing: DesignTokens.Spacing.xxs) {
                if !isAttached {
                    Button {
                        store.attach(to: session)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(DesignTokens.Typography.captionLarge)
                            .foregroundColor(DesignTokens.Colors.accentSecondary)
                            .frame(width: 28, height: 28)
                            .background(DesignTokens.Colors.accentSecondary.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("附加此会话")
                } else {
                    Button { store.detach() } label: {
                        Image(systemName: "stop.fill")
                            .font(DesignTokens.Typography.captionLarge)
                            .foregroundColor(Color.orange)
                            .frame(width: 28, height: 28)
                            .background(Color.orange.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("分离此会话")
                }

                Button {
                    if let name = selectedSessionName, name == session.name {
                        confirmKillSession = session
                    } else {
                        selectedSessionName = session.name
                        confirmKillSession = session
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("终止此会话")
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background {
            if isAttached {
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.accentSecondary.opacity(0.10),
                        DesignTokens.Colors.statusConnected.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.white.opacity(0.80)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isAttached
                        ? DesignTokens.Colors.accentSecondary.opacity(0.30)
                        : DesignTokens.Colors.borderPrimary,
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { selectedSessionName = session.name }
    }

    // MARK: - Windows Tab

    private var windowsTabContent: some View {
        VStack(spacing: 0) {
            // 会话选择器
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("选择会话：")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Picker("", selection: $windowsSessionName) {
                    Text("请选择").tag(String?.none)
                    ForEach(store.sessions, id: \.name) { s in
                        Text(s.name).tag(Optional(s.name))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                .onChange(of: windowsSessionName) { name in
                    if let name { store.refreshWindows(for: name) }
                }
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(height: 44)
            .background {
                Rectangle().fill(.thinMaterial)
                Rectangle().fill(Color.white.opacity(0.60))
            }
            .overlay(Divider(), alignment: .bottom)

            // 窗口卡片列表
            if let name = windowsSessionName,
               let session = store.sessions.first(where: { $0.name == name }) {
                if session.windows.isEmpty {
                    emptyWindowsView
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(session.windows, id: \.index) { window in
                                windowCard(window)
                                    .padding(.horizontal, DesignTokens.Spacing.md)
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.sm)
                    }
                }
            } else {
                emptyWindowsView
            }
        }
    }

    @ViewBuilder
    private func windowCard(_ window: TmuxWindow) -> some View {
        let isActive = window.isActive

        HStack(spacing: 10) {
            // 索引徽章
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(DesignTokens.Colors.surfaceHover)
                    .frame(width: 32, height: 32)
                Text("\(window.index)")
                    .font(DesignTokens.Typography.codeMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(window.name)
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                if isActive {
                    Text("活跃窗口")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
            }

            Spacer()

            if isActive {
                Text("Active")
                    .font(DesignTokens.Typography.captionSmall)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, DesignTokens.Spacing.xxxs)
                    .background(DesignTokens.Colors.accentPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background {
            if isActive {
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.accentPrimary.opacity(0.10),
                        DesignTokens.Colors.accentAI.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.white.opacity(0.80)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(
                    isActive
                        ? DesignTokens.Colors.accentPrimary.opacity(0.30)
                        : DesignTokens.Colors.borderPrimary,
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectWindow(index: window.index)
        }
    }

    // MARK: - Quick Actions Tab

    private var quickActionsTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 2×2 操作卡片
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(quickActionItems, id: \.title) { item in
                        quickActionCard(item)
                    }
                }

                // 常用命令列表
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("常用命令")
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    ForEach(commonCommands, id: \.command) { entry in
                        commonCommandRow(entry)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }

    private let quickActionItems: [(title: String, subtitle: String, icon: String, command: String, color: Color)] = [
        ("水平分割", "Ctrl+B then \"",  "rectangle.split.1x2",                    "tmux split-window -h",      DesignTokens.Colors.accentPrimary),
        ("垂直分割", "Ctrl+B then %",   "rectangle.split.2x1",                    "tmux split-window -v",      DesignTokens.Colors.accentSecondary),
        ("新建窗口", "Ctrl+B then C",   "plus.rectangle",                          "tmux new-window",           DesignTokens.Colors.statusConnecting),
        ("缩放窗格", "Ctrl+B then Z",   "arrow.up.left.and.arrow.down.right",      "tmux resize-pane -Z",       DesignTokens.Colors.accentAI)
    ]

    private let commonCommands: [(command: String, description: String)] = [
        ("tmux ls",                               "列出所有会话"),
        ("tmux attach -t <session>",              "附加到指定会话"),
        ("tmux kill-session -t <session>",        "终止指定会话"),
        ("tmux rename-session -t <old> <new>",    "重命名会话")
    ]

    @ViewBuilder
    private func quickActionCard(_ item: (title: String, subtitle: String, icon: String, command: String, color: Color)) -> some View {
        Button(action: { store.sendQuickCommand(item.command) }) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [item.color.opacity(0.15), item.color.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: item.icon)
                        .font(DesignTokens.Typography.labelXLarge)
                        .foregroundColor(item.color)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text(item.title)
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text(item.subtitle)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func commonCommandRow(_ entry: (command: String, description: String)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(entry.command)
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(entry.description)
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            Spacer()
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.command, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("复制到剪贴板")
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
    }

    // MARK: - 空/加载/不可用 状态

    private var checkingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
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
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(DesignTokens.Typography.displayXLarge)
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
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "rectangle.3.group")
                .font(DesignTokens.Typography.heroSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("没有活跃的 tmux 会话")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("点击「新建会话」创建一个会话")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyWindowsView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "macwindow")
                .font(DesignTokens.Typography.displayXLarge)
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("请先选择一个会话")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
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
                .font(DesignTokens.Typography.displayLarge)
                .foregroundColor(DesignTokens.Colors.statusError)

            VStack(spacing: DesignTokens.Spacing.xs) {
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
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                .fill(Color.white.opacity(0.95))
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
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(Color.white.opacity(0.60))
        }
        .overlay(alignment: .top) {
            Rectangle().fill(DesignTokens.Colors.borderFaint).frame(height: 0.5)
        }
    }
}

// MARK: - 预览

#Preview("tmux 管理器 - 会话列表") {
    let store = TmuxSessionStore(sessionId: UUID(), sendTarget: PreviewTmuxTarget())
    ZStack {
        Color.black.opacity(0.85)
        TmuxManagerView(
            store: store,
            serverLabel: "ubuntu@192.168.100.167",
            onClose: {}
        )
        .padding()
    }
    .frame(width: 700, height: 600)
}

// MARK: - 预览用占位 Target

private final class PreviewTmuxTarget: TmuxSendTarget {
    func sendTmuxCommand(_ command: String) {}
}
