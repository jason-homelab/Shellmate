import SwiftUI

// MARK: - SSH Config 导入向导

/// ~/.ssh/config 导入向导
/// 解析本机 SSH 配置文件，让用户勾选要导入的会话条目
struct SSHConfigImportView: View {

    // MARK: - 回调

    var onImport: ([Session]) -> Void
    var onCancel: () -> Void

    // MARK: - 状态

    @State private var entries: [SSHConfigEntry] = []
    @State private var selected: Set<UUID> = []
    @State private var parseError: String?
    @State private var isLoading = true
    @State private var searchText = ""

    // MARK: - 过滤后的条目

    private var filteredEntries: [SSHConfigEntry] {
        if searchText.isEmpty { return entries }
        let q = searchText.lowercased()
        return entries.filter {
            $0.hostPattern.lowercased().contains(q)
            || $0.hostname.lowercased().contains(q)
            || $0.username.lowercased().contains(q)
        }
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 560, height: 480)
        .background(DesignTokens.Colors.surfacePanel)
        .onAppear { loadConfig() }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary.opacity(0.12))
                    .frame(width: 40, height: 40)
                AppIcon.terminal.image
                    .font(DesignTokens.Typography.displayXSmall)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text("从 SSH 配置导入")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("读取 ~/.ssh/config，勾选要导入的主机")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Button(action: onCancel) {
                AppIcon.close.image
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 14)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            Spacer()
            ProgressView("正在读取 ~/.ssh/config…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        } else if let error = parseError {
            errorView(message: error)
        } else if entries.isEmpty {
            emptyView
        } else {
            entryListView
        }
    }

    // MARK: - 错误视图

    private func errorView(message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            AppIcon.warning.image
                .font(DesignTokens.Typography.displayXLarge)
                .foregroundColor(DesignTokens.Colors.statusConnecting)
            Text("无法读取配置文件")
                .font(DesignTokens.Typography.labelLargeAlt)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Text(message)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空状态视图

    private var emptyView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            AppIcon.docText.image
                .font(DesignTokens.Typography.displayXLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("未找到可导入的主机")
                .font(DesignTokens.Typography.labelLargeAlt)
                .foregroundColor(DesignTokens.Colors.textPrimary)
            Text("~/.ssh/config 中没有具体的主机条目\n（通配符条目 Host * 已被跳过）")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 条目列表

    private var entryListView: some View {
        VStack(spacing: 0) {
            // 搜索栏 + 全选
            HStack(spacing: DesignTokens.Spacing.sm) {
                AppIcon.search.image
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                TextField("搜索主机名…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.bodyMedium)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        AppIcon.dismiss.image
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(DesignTokens.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )

            // 全选/全取消行
            HStack {
                Text("\(filteredEntries.count) 个主机条目")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Spacer()
                Button(allSelected ? "取消全选" : "全选") {
                    if allSelected {
                        selected.subtract(filteredEntries.map(\.id))
                    } else {
                        selected.formUnion(filteredEntries.map(\.id))
                    }
                }
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.xxxs)
            .padding(.vertical, DesignTokens.Spacing.xs)

            // 条目列表
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.xxs) {
                    ForEach(filteredEntries) { entry in
                        EntryRowView(
                            entry: entry,
                            isSelected: selected.contains(entry.id),
                            onToggle: { toggleSelection(entry) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - 底部按钮

    private var footerView: some View {
        HStack {
            // 已选数量提示
            if !selected.isEmpty {
                Text("已选 \(selected.count) 个")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Button("取消", action: onCancel)
                .buttonStyle(.bordered)

            Button {
                importSelected()
            } label: {
                Label("导入选中", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - 辅助

    private var allSelected: Bool {
        !filteredEntries.isEmpty && filteredEntries.allSatisfy { selected.contains($0.id) }
    }

    private func toggleSelection(_ entry: SSHConfigEntry) {
        if selected.contains(entry.id) {
            selected.remove(entry.id)
        } else {
            selected.insert(entry.id)
        }
    }

    private func loadConfig() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            do {
                if !SSHConfigParser.configFileExists {
                    await MainActor.run {
                        parseError = "~/.ssh/config 文件不存在。\n请先配置 SSH 连接或手动创建该文件。"
                        isLoading = false
                    }
                    return
                }
                let parsed = try SSHConfigParser.parse()
                await MainActor.run {
                    entries = parsed
                    // 默认全选非通配符条目
                    selected = Set(parsed.filter { !$0.isWildcard }.map(\.id))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    parseError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func importSelected() {
        let sessions = entries
            .filter { selected.contains($0.id) }
            .map { $0.toSession() }
        onImport(sessions)
    }
}

// MARK: - 条目行视图

private struct EntryRowView: View {
    let entry: SSHConfigEntry
    let isSelected: Bool
    let onToggle: () -> Void

    // 拆分子表达式以避免编译器类型推断超时
    private var hostPatternText: some View {
        Text(entry.hostPattern)
            .font(DesignTokens.Typography.labelLarge)
            .foregroundColor(DesignTokens.Colors.textPrimary)
    }

    @ViewBuilder
    private var wildcardBadge: some View {
        if entry.isWildcard {
            Text("通配符")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.statusConnecting)
                .padding(.horizontal, DesignTokens.Spacing.micro)
                .padding(.vertical, DesignTokens.Spacing.px)
                .background(DesignTokens.Colors.statusConnecting.opacity(0.10))
                .clipShape(Capsule())
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // 勾选框
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(isSelected
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)

            // 主机图标
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary.opacity(0.08))
                    .frame(width: 28, height: 28)
                AppIcon.serverRack.image
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            // 信息
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    hostPatternText
                    wildcardBadge
                }
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    if !entry.username.isEmpty {
                        Text(entry.username + "@")
                            .font(DesignTokens.Typography.codeTiny)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    Text(entry.hostname)
                        .font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    if entry.port != 22 {
                        Text(":\(entry.port)")
                            .font(DesignTokens.Typography.codeTiny)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            // 额外标记
            HStack(spacing: DesignTokens.Spacing.xxs) {
                if entry.identityFile != nil {
                    Label("密钥", systemImage: "key.fill")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.accentSecondary)
                        .labelStyle(.iconOnly)
                        .help("使用私钥认证")
                }
                if entry.proxyJump != nil {
                    Label("跳板", systemImage: "arrow.triangle.branch")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.accentIndigo)
                        .labelStyle(.iconOnly)
                        .help("ProxyJump: \(entry.proxyJump!)")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(isSelected
            ? DesignTokens.Colors.accentPrimary.opacity(0.05)
            : DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(isSelected
                    ? DesignTokens.Colors.accentPrimary.opacity(0.25)
                    : DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

// MARK: - 预览

#Preview("SSH Config 导入向导") {
    SSHConfigImportView(
        onImport: { sessions in print("导入 \(sessions.count) 个会话") },
        onCancel: {}
    )
}
