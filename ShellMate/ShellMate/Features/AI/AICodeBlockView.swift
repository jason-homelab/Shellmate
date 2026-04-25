import SwiftUI
import AppKit

// MARK: - AI 代码块视图

/// 代码块展示组件（深色背景 #1E1E1E，等宽字体，复制/插入终端按钮）
/// 对齐 Figma-Spec-v2 §09 代码块规范
struct AICodeBlockView: View {

    let code: String
    let language: String?
    /// 一键插入终端（AI-03），nil 表示不显示该按钮
    var onInsert: ((String) -> Void)?

    @State private var isCopied: Bool = false
    @State private var isInserted: Bool = false

    /// 提取纯命令文本（去除 ⚠️ 警告行和首尾空白）
    private var cleanCommand: String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("⚠️") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏（语言标签 + 操作按钮）
            HStack(spacing: 6) {
                if let lang = language, !lang.isEmpty {
                    Text(lang.lowercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                Spacer()
                copyButton
                if onInsert != nil { insertButton }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DesignTokens.Colors.glassLight)

            Divider()

            // 代码内容（横向可滚动）
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.trimmingCharacters(in: .newlines))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .background(DesignTokens.Colors.glassUltraLight)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
        )
    }

    // MARK: - 复制按钮

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            withAnimation(.easeInOut(duration: 0.15)) { isCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { isCopied = false }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                Text(isCopied ? "已复制" : "复制")
                    .font(.system(size: 10))
            }
            .foregroundColor(isCopied
                ? DesignTokens.Colors.statusConnected
                : DesignTokens.Colors.textTertiary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 插入终端按钮

    private var insertButton: some View {
        Button {
            onInsert?(cleanCommand)
            withAnimation(.easeInOut(duration: 0.15)) { isInserted = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { isInserted = false }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: isInserted ? "checkmark.circle.fill" : "terminal")
                    .font(.system(size: 10))
                Text(isInserted ? "已插入" : "插入终端")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isInserted
                ? DesignTokens.Colors.statusConnected
                : DesignTokens.Colors.accentPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                isInserted
                    ? DesignTokens.Colors.statusConnected.opacity(0.12)
                    : DesignTokens.Colors.accentPrimary.opacity(0.10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("将命令插入当前终端并执行")
    }
}

// MARK: - 预览

#Preview("代码块 - bash") {
    AICodeBlockView(
        code: "#!/bin/bash\ndf -h\ndu -sh /var/log/*",
        language: "bash",
        onInsert: { _ in }
    )
    .frame(width: 360)
    .padding()
    .background(DesignTokens.Colors.surfacePanel)
}

#Preview("代码块 - 警告命令") {
    AICodeBlockView(
        code: "⚠️ 高风险命令，请确认后再执行\nrm -rf /tmp/old_data",
        language: "bash",
        onInsert: { _ in }
    )
    .frame(width: 360)
    .padding()
    .background(DesignTokens.Colors.surfacePanel)
}
