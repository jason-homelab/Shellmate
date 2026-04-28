import SwiftUI

// MARK: - ContentView 弹窗与菜单

extension ContentView {

    // MARK: - 会话表单弹窗

    var sessionFormSheet: some View {
        SessionFormSheet(
            editingSession: sessionStore.editingSession,
            defaultGroupId: sessionStore.defaultGroupId,
            groups: groupStore.groups,
            onSave: { session in
                Task {
                    await sessionStore.saveSession(session)
                    sessionStore.defaultGroupId = nil
                    sessionStore.dismissSessionForm()
                }
            },
            onCancel: {
                sessionStore.defaultGroupId = nil
                sessionStore.dismissSessionForm()
            }
        )
    }

    // MARK: - 分组表单弹窗

    var groupFormSheet: some View {
        GroupFormSheet(
            editingGroup: groupStore.editingGroup,
            onSave: { group in
                Task {
                    await groupStore.saveGroup(group)
                    groupStore.dismissGroupForm()
                }
            },
            onCancel: {
                groupStore.dismissGroupForm()
            }
        )
    }

    // MARK: - 导入/导出 Popover

    var sessionShareMenu: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text("会话配置")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, 10)
                .padding(.bottom, DesignTokens.Spacing.xxxs)

            Button {
                showSharePopover = false
                showImportExportDialog = true
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "arrow.up.arrow.down.square")
                        .frame(width: 16)
                    Text("导入 / 导出会话…")
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .contentShape(Rectangle())

            Divider()
                .padding(.horizontal, DesignTokens.Spacing.md)

            Text("迁移")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.xs)
                .padding(.bottom, DesignTokens.Spacing.xxxs)

            Button {
                showSharePopover = false
                showSSHConfigImport = true
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "terminal")
                        .frame(width: 16)
                    Text("从 ~/.ssh/config 导入…")
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .contentShape(Rectangle())

            Divider()
                .padding(.horizontal, DesignTokens.Spacing.md)

            Text("密码与私钥不会包含在导出文件中")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, 10)
                .padding(.top, DesignTokens.Spacing.xxxs)
        }
        .frame(width: 240)
    }

    // MARK: - SSH Config 导入弹窗

    var sshConfigImportSheet: some View {
        SSHConfigImportView(
            onImport: { sessions in
                showSSHConfigImport = false
                Task {
                    for session in sessions {
                        await sessionStore.saveSession(session)
                    }
                }
            },
            onCancel: {
                showSSHConfigImport = false
            }
        )
    }

    // MARK: - 语言选择器菜单

    var languagePickerMenu: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            languageOption(label: "中文", tag: "zh")
            languageOption(label: "English", tag: "en")
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(minWidth: 120)
    }

    func languageOption(label: String, tag: String) -> some View {
        Button(action: {
            appLanguage = tag
            showLanguagePicker = false
        }) {
            HStack {
                Text(label)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                if appLanguage == tag {
                    Image(systemName: "checkmark")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
