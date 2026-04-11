import SwiftUI

// MARK: - iCloud 同步状态

enum CloudSyncStatus {
    case synced(lastSync: Date)
    case syncing
    case failed(reason: String)
    case disabled

    var iconName: String {
        switch self {
        case .synced:   return "checkmark.icloud.fill"
        case .syncing:  return "arrow.clockwise.icloud"
        case .failed:   return "exclamationmark.icloud.fill"
        case .disabled: return "icloud.slash.fill"
        }
    }

    var color: Color {
        switch self {
        case .synced:   return Color(hex: "#2DCE7A")
        case .syncing:  return Color.accentColor
        case .failed:   return Color(hex: "#F04060")
        case .disabled: return Color(hex: "#6B6A78")
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .synced:   return "已同步"
        case .syncing:  return "同步中…"
        case .failed:   return "同步失败"
        case .disabled: return "iCloud 同步未启用"
        }
    }
}

// MARK: - 冲突解决策略

enum CloudConflictStrategy: String, CaseIterable {
    case latestWins = "latestWins"
    case localWins  = "localWins"
    case askEachTime = "askEachTime"

    var title: LocalizedStringKey {
        switch self {
        case .latestWins:  return "以 iCloud 版本为准（最新修改优先）"
        case .localWins:   return "以本机版本为准"
        case .askEachTime: return "每次冲突时手动选择"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .latestWins:  return "多台设备同时修改时，取最后编辑时间较晚的版本"
        case .localWins:   return "同步时始终以本设备数据覆盖 iCloud"
        case .askEachTime: return "出现版本冲突时弹出对话框让用户选择"
        }
    }
}

// MARK: - S05 iCloud 同步设置视图

/// S05 — iCloud 同步设置面板
struct CloudSyncSettingsView: View {

    // MARK: - 持久化设置

    @AppStorage("sync.enabled")          private var syncEnabled: Bool   = true
    @AppStorage("sync.sessions")         private var syncSessions: Bool  = true
    @AppStorage("sync.commands")         private var syncCommands: Bool  = true
    @AppStorage("sync.highlights")       private var syncHighlights: Bool = true
    @AppStorage("sync.appearance")       private var syncAppearance: Bool = false
    @AppStorage("sync.tunnels")          private var syncTunnels: Bool   = false
    @AppStorage("sync.conflictStrategy") private var conflictStrategy: String = CloudConflictStrategy.latestWins.rawValue

    // MARK: - 状态

    @State private var syncStatus: CloudSyncStatus = .synced(lastSync: Date().addingTimeInterval(-120))
    @State private var isSyncing: Bool = false

    // MARK: - 计算属性

    private var appleIDString: LocalizedStringKey {
        // 尝试从 NSUbiquitousKeyValueStore 或系统获取账号信息
        FileManager.default.ubiquityIdentityToken != nil
            ? "已登录 iCloud"
            : "未登录 Apple ID"
    }

    private var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ① 同步总开关
                settingsSection(title: "iCloud 同步") {
                    syncToggleSection
                }

                Divider().padding(.vertical, 14)

                // ② 同步范围
                settingsSection(title: "同步范围") {
                    syncScopeSection
                }
                .disabled(!syncEnabled)
                .opacity(syncEnabled ? 1 : 0.4)

                Divider().padding(.vertical, 14)

                // ③ 同步状态
                settingsSection(title: "同步状态") {
                    syncStatusSection
                }
                .disabled(!syncEnabled)
                .opacity(syncEnabled ? 1 : 0.4)

                Divider().padding(.vertical, 14)

                // ④ 冲突解决
                settingsSection(title: "冲突解决策略") {
                    conflictResolutionSection
                }
                .disabled(!syncEnabled)
                .opacity(syncEnabled ? 1 : 0.4)
            }
            .padding(18)
        }
    }

    // MARK: - 同步总开关

    private var syncToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: $syncEnabled) {
                    Text("通过 iCloud 同步会话配置")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .toggleStyle(.switch)
                .disabled(!iCloudAvailable)

                Spacer()

                Text(appleIDString)
                    .font(.system(size: 10))
                    .foregroundColor(iCloudAvailable
                        ? DesignTokens.Colors.textDisabled
                        : DesignTokens.Colors.statusError)
            }

            // 安全说明卡片
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .padding(.top, 1)

                Text("会话名称、主机地址、端口、用户名、分组等配置将加密同步至 iCloud。SSH 密码和私钥不参与同步，始终以 AES-256-GCM 加密存储于本设备本地数据库。")
                    .font(.system(size: 10.5))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineSpacing(2)
            }
            .padding(12)
            .background(DesignTokens.Colors.surfaceWindow)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    // MARK: - 同步范围

    private var syncScopeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            syncScopeToggle(
                isOn: $syncSessions,
                label: "会话与分组",
                hint: "所有已保存的 SSH 会话和分组结构"
            )
            syncScopeToggle(
                isOn: $syncCommands,
                label: "快捷命令",
                hint: "快捷命令集及命令内容"
            )
            syncScopeToggle(
                isOn: $syncHighlights,
                label: "关键词高亮规则",
                hint: "所有高亮规则集配置"
            )
            syncScopeToggle(
                isOn: $syncAppearance,
                label: "终端外观设置",
                hint: "颜色主题、字体大小等外观偏好（不含字体文件本身）"
            )
            syncScopeToggle(
                isOn: $syncTunnels,
                label: "隧道规则",
                hint: "端口转发规则（不含绑定的会话密码）"
            )
        }
    }

    private func syncScopeToggle(isOn: Binding<Bool>, label: LocalizedStringKey, hint: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text(hint)
                        .font(.system(size: 9.5))
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    // MARK: - 同步状态

    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 状态卡片
            HStack(spacing: 12) {
                Image(systemName: syncStatus.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(syncStatus.color)
                    .rotationEffect(isSyncing ? .degrees(360) : .degrees(0))
                    .animation(
                        isSyncing
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: isSyncing
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(syncStatus.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(syncStatus.color)

                    if case .synced(let date) = syncStatus {
                        Text("上次同步：\(relativeDateString(date))")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textDisabled)
                    } else if case .failed(let reason) = syncStatus {
                        Text(reason)
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textDisabled)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(DesignTokens.Colors.surfaceWindow)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            // 立即同步按钮
            Button(action: triggerSync) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.icloud")
                        .font(.system(size: 11))
                    Text("立即同步")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isSyncing)
        }
    }

    // MARK: - 冲突解决

    private var conflictResolutionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(CloudConflictStrategy.allCases, id: \.rawValue) { strategy in
                conflictStrategyRow(strategy)
            }
        }
    }

    private func conflictStrategyRow(_ strategy: CloudConflictStrategy) -> some View {
        let isSelected = conflictStrategy == strategy.rawValue

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentColor : DesignTokens.Colors.textDisabled, lineWidth: 1.5)
                    )

                Button(action: { conflictStrategy = strategy.rawValue }) {
                    Text(strategy.title)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text(strategy.subtitle)
                .font(.system(size: 9.5))
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .padding(.leading, 14)
        }
    }

    // MARK: - 辅助

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)
            content()
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return String(localized: "刚刚") }
        if diff < 3600 { return String(format: String(localized: "%lld 分钟前"), Int(diff / 60)) }
        if diff < 86400 { return String(format: String(localized: "%lld 小时前"), Int(diff / 3600)) }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }

    private func triggerSync() {
        isSyncing = true
        syncStatus = .syncing

        // 模拟同步过程（实际由 NSPersistentCloudKitContainer 驱动）
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                isSyncing = false
                syncStatus = .synced(lastSync: Date())
            }
        }
    }
}

// MARK: - 预览

#Preview("iCloud 同步设置") {
    CloudSyncSettingsView()
        .frame(width: 480, height: 520)
}
