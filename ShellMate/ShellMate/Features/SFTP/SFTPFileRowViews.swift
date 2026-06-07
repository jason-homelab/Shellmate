import SwiftUI

// MARK: - 本地文件行视图

/// 本地文件/目录行（双行布局：文件名 + 大小+时间）
struct LocalFileRowView: View {

    let item: LocalFileItem
    let isSelected: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(item.isDirectory
                        ? DesignTokens.Colors.accentPrimary.opacity(0.10)
                        : DesignTokens.Colors.textTertiary.opacity(0.10))
                    .frame(width: 24, height: 24)
                Image(systemName: item.sfSymbolName)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(item.isDirectory
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.px) {
                Text(item.name)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Text(item.formattedSize)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text(item.formattedDate)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .opacity(isHovering ? 1 : 0)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(isSelected
                    ? DesignTokens.Colors.accentPrimary.opacity(0.10)
                    : (isHovering ? DesignTokens.Colors.surfaceHover : Color.clear))
        )
        .overlay(
            isSelected
                ? RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.30), lineWidth: 1)
                : nil
        )
        .animation(DesignTokens.Animation.hover, value: isHovering)
        .onHover { isHovering = $0 }
        .help(item.name)
    }
}

// MARK: - 远程文件行视图

/// 远程文件/目录行（双行布局：文件名 + 大小+时间）
struct RemoteFileRowView: View {

    let item: SFTPFileItem
    let isSelected: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(item.fileType.isDirectory
                        ? DesignTokens.Colors.statusConnected.opacity(0.10)
                        : DesignTokens.Colors.textTertiary.opacity(0.10))
                    .frame(width: 24, height: 24)
                Image(systemName: item.fileType.sfSymbolName)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.px) {
                Text(item.name)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Text(item.formattedSize)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text(item.formattedDate)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.fileType.isDirectory {
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .opacity(isHovering ? 1 : 0)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(isSelected
                    ? DesignTokens.Colors.statusConnected.opacity(0.10)
                    : (isHovering ? DesignTokens.Colors.surfaceHover : Color.clear))
        )
        .overlay(
            isSelected
                ? RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.statusConnected.opacity(0.30), lineWidth: 1)
                : nil
        )
        .animation(DesignTokens.Animation.hover, value: isHovering)
        .onHover { isHovering = $0 }
        .help(item.name + "  " + item.permissionsString)
    }

    private var iconColor: Color {
        switch item.fileType {
        case .directory:    return DesignTokens.Colors.statusConnected
        case .regularFile:  return DesignTokens.Colors.textSecondary
        case .symlink:      return DesignTokens.Colors.accentSecondary
        case .other:        return DesignTokens.Colors.textSecondary
        }
    }
}
