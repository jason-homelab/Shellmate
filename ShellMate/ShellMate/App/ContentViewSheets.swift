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
        VStack(alignment: .leading, spacing: 4) {
            Text("会话配置")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 2)

            Button {
                showSharePopover = false
                showImportExportDialog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down.square")
                        .frame(width: 16)
                    Text("导入 / 导出会话…")
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .contentShape(Rectangle())

            Divider()
                .padding(.horizontal, 12)

            Text("迁移")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 2)

            Button {
                showSharePopover = false
                showSSHConfigImport = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .frame(width: 16)
                    Text("从 ~/.ssh/config 导入…")
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .contentShape(Rectangle())

            Divider()
                .padding(.horizontal, 12)

            Text("密码与私钥不会包含在导出文件中")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .padding(.top, 2)
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
        VStack(alignment: .leading, spacing: 2) {
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
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                if appLanguage == tag {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
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
