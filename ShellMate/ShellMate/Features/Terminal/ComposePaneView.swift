import SwiftUI
import AppKit

// MARK: - O02 Compose Pane（命令编辑区）

/// Compose Pane — 停靠于终端底部的多行命令编辑区
/// 规格：与 TerminalPane 同宽，默认高度 120pt（60–200pt 可拖拽调整）
struct ComposePaneView: View {

    /// 发送命令回调
    var onSend: (String) -> Void

    /// 关闭面板回调
    var onClose: () -> Void

    // MARK: - 状态

    @State private var content: String = ""
    @State private var sendLineByLine: Bool = false
    @State private var lineDelay: Int = 50
    @State private var language: ComposeLanguage = .bash
    @State private var paneHeight: CGFloat = 120
    @State private var isDragging: Bool = false

    private let minHeight: CGFloat = 60
    private let maxHeight: CGFloat = 200

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽调整线
            resizeHandle

            // 代码编辑区
            codeEditorArea

            // 操作栏
            actionBar
        }
        .frame(height: paneHeight)
        .background(DesignTokens.Colors.terminalBackground)
    }

    // MARK: - 子视图

    private var resizeHandle: some View {
        ZStack {
            Rectangle()
                .fill(isDragging ? DesignTokens.Colors.accentPrimary.opacity(0.3) : DesignTokens.Colors.borderFaint)

            // 居中三点装饰
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(DesignTokens.Colors.borderSubtle)
                        .frame(width: 2, height: 2)
                }
            }
        }
        .frame(height: 4)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let delta = -value.translation.height  // 向上拖 = 增大高度
                    let newHeight = (paneHeight + delta).clamped(to: minHeight...maxHeight)
                    paneHeight = newHeight
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .cursor(.resizeUpDown)
    }

    private var codeEditorArea: some View {
        HStack(spacing: 0) {
            // 行号列
            lineNumberColumn

            // 代码内容区
            TextEditor(text: $content)
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.terminalText)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.top, 6)
                .padding(.leading, 10)
                .padding(.trailing, 4)
        }
        .background(DesignTokens.Colors.terminalBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignTokens.Colors.borderSubtle),
            alignment: .top
        )
        .frame(maxHeight: .infinity)
    }

    private var lineNumberColumn: some View {
        let lines = content.components(separatedBy: "\n")
        return ZStack(alignment: .topTrailing) {
            DesignTokens.Colors.surfaceOverlay
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lines.indices), id: \.self) { i in
                    Text("\(i + 1)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                        .frame(height: 20, alignment: .trailing)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
        }
        .frame(width: 28)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignTokens.Colors.borderFaint),
            alignment: .trailing
        )
    }

    private var actionBar: some View {
        HStack(spacing: 6) {
            // 发送按钮
            Button(action: sendContent) {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 10))
                    Text("发送")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.return, modifiers: .control)

            Divider().frame(height: 16)

            // 逐行发送切换
            Toggle("逐行", isOn: $sendLineByLine)
                .toggleStyle(.button)
                .font(.system(size: 11))
                .controlSize(.small)

            if sendLineByLine {
                HStack(spacing: 4) {
                    Text("延迟")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                    TextField("50", value: $lineDelay, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(DesignTokens.Typography.codeSmall)
                        .frame(width: 44)
                    Text("ms")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                }
            }

            Spacer()

            // 语言选择
            Picker("", selection: $language) {
                ForEach(ComposeLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .frame(width: 80)
            .font(DesignTokens.Typography.codeSmall)
            .foregroundColor(DesignTokens.Colors.textSecondary)

            Divider().frame(height: 16)

            // 清空并关闭
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textDisabled)
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(DesignTokens.Colors.surfaceToolbar)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignTokens.Colors.borderFaint),
            alignment: .top
        )
    }

    // MARK: - 操作

    private func sendContent() {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if sendLineByLine {
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            for (index, line) in lines.enumerated() {
                let delay = DispatchTime.now() + .milliseconds(lineDelay * index)
                DispatchQueue.main.asyncAfter(deadline: delay) {
                    onSend(line + "\r")
                }
            }
        } else {
            onSend(content)
        }
    }
}

// MARK: - 语言类型

enum ComposeLanguage: String, CaseIterable {
    case bash, sh, python, ruby, zsh

    var displayName: String { rawValue }
}

// MARK: - 辅助扩展

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
