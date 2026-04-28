import SwiftUI
import AppKit

/// 终端文本视图
/// 使用 NSTextView 实现可交互的终端显示，支持键盘输入
struct TerminalTextView: NSViewRepresentable {

    // MARK: - 属性

    /// 终端输出内容
    @Binding var output: String

    /// 键盘输入回调
    var onKeyPress: ((String) -> Void)?

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(red: 0.047, green: 0.047, blue: 0.055, alpha: 1.0)

        let textView = TerminalNSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.backgroundColor = NSColor(red: 0.047, green: 0.047, blue: 0.055, alpha: 1.0)
        textView.textColor = NSColor(red: 0.933, green: 0.929, blue: 0.961, alpha: 1.0) // textPrimary
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.allowsUndo = false

        // 设置键盘输入回调
        textView.onKeyPress = onKeyPress

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        // 更新文本内容
        let currentText = textView.string
        if currentText != output {
            textView.string = output

            // 自动滚动到底部
            if let scrollView = textView.enclosingScrollView {
                let clipView = scrollView.contentView
                let documentView = scrollView.documentView!
                let newScrollOrigin = NSPoint(
                    x: 0,
                    y: max(0, documentView.frame.height - clipView.bounds.height)
                )
                clipView.scroll(to: newScrollOrigin)
            }
        }

        // 确保获取焦点
        if textView.window?.firstResponder != textView {
            textView.window?.makeFirstResponder(textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var textView: TerminalNSTextView?
    }
}

// MARK: - 自定义 NSTextView

/// 支持键盘输入的终端 NSTextView
class TerminalNSTextView: NSTextView {

    /// 键盘输入回调
    var onKeyPress: ((String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else {
            super.keyDown(with: event)
            return
        }

        // 处理特殊按键
        switch event.keyCode {
        case 36: // Return
            onKeyPress?("\r")
        case 51: // Backspace
            onKeyPress?("\u{7F}")
        case 53: // Escape
            onKeyPress?("\u{1B}")
        case 123: // Left arrow
            onKeyPress?("\u{1B}[D")
        case 124: // Right arrow
            onKeyPress?("\u{1B}[C")
        case 125: // Down arrow
            onKeyPress?("\u{1B}[B")
        case 126: // Up arrow
            onKeyPress?("\u{1B}[A")
        case 48: // Tab
            onKeyPress?("\t")
        default:
            // 处理 Ctrl 组合键
            if event.modifierFlags.contains(.control) {
                if let char = characters.first,
                   let asciiValue = char.asciiValue {
                    // Ctrl-A 到 Ctrl-Z 对应 ASCII 1-26
                    if char.isLetter {
                        let ctrlChar = Character(UnicodeScalar(asciiValue & 0x1F))
                        onKeyPress?(String(ctrlChar))
                        return
                    }
                    // Ctrl-C 特殊处理
                    if char == "c" || char == "C" {
                        onKeyPress?("\u{03}")
                        return
                    }
                }
            }

            // 普通字符
            if !characters.isEmpty {
                onKeyPress?(characters)
            }
        }
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        // 不在文本视图中插入文本，只发送到 SSH
        if let str = string as? String {
            onKeyPress?(str)
        }
    }

    override func paste(_ sender: Any?) {
        // 处理粘贴
        if let string = NSPasteboard.general.string(forType: .string) {
            onKeyPress?(string)
        }
    }

    // 绘制光标
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 绘制块状光标
        if window?.firstResponder == self {
            let cursorRect = NSRect(
                x: textContainerInset.width + (string as NSString).size(withAttributes: [.font: font!]).width,
                y: bounds.height - textContainerInset.height - (font?.pointSize ?? 13) - 2,
                width: 8,
                height: font?.pointSize ?? 13
            )

            // 闪烁效果通过定时器实现（简化版：始终显示）
            NSColor(red: 0.933, green: 0.929, blue: 0.961, alpha: 0.7).setFill()
            let path = NSBezierPath(rect: cursorRect)
            path.fill()
        }
    }
}

// MARK: - 预览

#Preview("终端文本视图") {
    TerminalTextView(
        output: .constant("ubuntu@server:~$ ls -la\ntotal 48\ndrwxr-xr-x  12 ubuntu ubuntu 4096 Mar 19 12:00 .\ndrwxr-xr-x   3 root   root   4096 Mar 19 11:00 ..\n-rw-r--r--   1 ubuntu ubuntu  220 Mar 19 11:00 .bash_logout\n-rw-r--r--   1 ubuntu ubuntu 3771 Mar 19 11:00 .bashrc\nubuntu@server:~$ "),
        onKeyPress: { key in
            AppLogger.general.debug("Key pressed: \(key.debugDescription)")
        }
    )
    .frame(width: 600, height: 400)
}
