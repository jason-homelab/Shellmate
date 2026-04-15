import SwiftUI

// MARK: - 密码管理弹窗（任务 13.16）

/// 列出所有已在金库中保存密码凭据的会话，支持逐条删除
/// 对齐 Figma-Spec-v2 §14-§2：600px 宽，orange key 图标，圆角卡片行，Eye/EyeOff 密码切换
struct PasswordManagerView: View {

    // MARK: - 属性

    let sessions: [Session]
    var onClose: (() -> Void)?

    // MARK: - 状态

    /// 已保存密码的会话 ID 集合（异步加载）
    @State private var savedSessionIds: Set<UUID> = []
    @State private var isLoading: Bool = true
    /// 待确认删除的会话
    @State private var pendingDeleteSession: Session? = nil
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil
    /// 当前已展开显示明文密码的会话 ID 集合
    @State private var visiblePasswordIds: Set<UUID> = []
    /// 已从 Keychain 读取的明文密码缓存（仅内存，不持久化）
    @State private var revealedPasswords: [UUID: String] = [:]

    // MARK: - 计算属性

    private var savedSessions: [Session] {
        sessions.filter { savedSessionIds.contains($0.id) }
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentArea
        }
        .frame(width: 600)
        .background(DesignTokens.Colors.surfacePanel)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .task {
            await loadSavedSessions()
        }
        .alert("确认删除", isPresented: Binding(
            get: { pendingDeleteSession != nil },
            set: { if !$0 { pendingDeleteSession = nil } }
        )) {
            Button("取消", role: .cancel) { pendingDeleteSession = nil }
            Button("删除", role: .destructive) {
                if let session = pendingDeleteSession {
                    Task { await deleteCredential(for: session) }
                }
            }
        } message: {
            if let session = pendingDeleteSession {
                Text("将删除「\(session.name)」保存的密码，下次连接时需要重新输入。")
            }
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // orange key 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DesignTokens.Colors.statusConnecting.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: "key.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.statusConnecting)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("密码管理")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("管理已保存的 SSH 登录密码")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            loadingView
        } else if savedSessions.isEmpty {
            emptyStateView
        } else {
            sessionListView
        }

        // 错误提示
        if let error = errorMessage {
            Text(error)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.statusError)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.sm)
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .controlSize(.small)
            Text("加载中…")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xxl)
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "key.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(DesignTokens.Colors.textDisabled)
            Text("暂无已保存的密码")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("在新建会话时勾选\"记住密码\"，密码将安全加密存储在本机")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xxl)
    }

    // MARK: - 会话列表

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(savedSessions) { session in
                    sessionRow(session)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(maxHeight: 400)
    }

    // MARK: - 单行

    private func sessionRow(_ session: Session) -> some View {
        let isVisible = visiblePasswordIds.contains(session.id)
        return HStack(spacing: DesignTokens.Spacing.md) {
            // 会话信息
            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(session.username)@\(session.host):\(session.port)")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // 掩码 / 明文密码 + Eye 切换按钮
            HStack(spacing: 4) {
                Text(isVisible
                     ? (revealedPasswords[session.id] ?? String(repeating: "•", count: 12))
                     : String(repeating: "•", count: 12))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Button {
                    togglePasswordVisibility(session)
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(isVisible ? "隐藏密码" : "显示密码")
            }

            // 删除按钮
            Button {
                pendingDeleteSession = session
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .frame(width: 28, height: 28)
                    .background(DesignTokens.Colors.statusError.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
        .padding(DesignTokens.Spacing.md)
        .background(Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 1)
        )
    }

    // MARK: - 密码可见性切换

    /// 尝试从 Keychain 读取密码并切换显示状态
    private func togglePasswordVisibility(_ session: Session) {
        if visiblePasswordIds.contains(session.id) {
            visiblePasswordIds.remove(session.id)
            revealedPasswords.removeValue(forKey: session.id)
        } else {
            if let password = try? KeychainService.shared.getPassword(for: session.id, type: .password) {
                revealedPasswords[session.id] = password
                visiblePasswordIds.insert(session.id)
            } else {
                errorMessage = "无法从安全存储中读取密码"
            }
        }
    }

    // MARK: - 数据操作

    /// 并发检查所有会话是否有已保存密码
    private func loadSavedSessions() async {
        isLoading = true
        defer { isLoading = false }

        await withTaskGroup(of: (UUID, Bool).self) { group in
            for session in sessions {
                group.addTask {
                    let has = await CredentialVault.shared.exists(sessionId: session.id, type: .password)
                    return (session.id, has)
                }
            }
            var result: Set<UUID> = []
            for await (id, has) in group {
                if has { result.insert(id) }
            }
            await MainActor.run { savedSessionIds = result }
        }
    }

    /// 删除指定会话的密码凭据
    private func deleteCredential(for session: Session) async {
        isDeleting = true
        pendingDeleteSession = nil
        defer { isDeleting = false }

        do {
            try await CredentialVault.shared.delete(sessionId: session.id, type: .password)
            await MainActor.run {
                savedSessionIds.remove(session.id)
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "删除失败：\(error.localizedDescription)"
            }
        }
    }
}
