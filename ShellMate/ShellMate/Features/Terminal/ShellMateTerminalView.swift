import SwiftUI
import AppKit

// MARK: - SwiftTerm 协议模拟
// 注意：实际项目中需要 import SwiftTerm 并使用真实的类型

/// 终端视图委托协议
protocol ShellMateTerminalViewDelegate: AnyObject {
    /// 终端请求发送数据
    func terminalView(_ view: ShellMateTerminalView, send data: Data)

    /// 终端请求发送字符串
    func terminalView(_ view: ShellMateTerminalView, send string: String)

    /// 终端尺寸变化
    func terminalView(_ view: ShellMateTerminalView, sizeChanged newSize: TerminalSize)

    /// 终端标题变化
    func terminalView(_ view: ShellMateTerminalView, titleChanged newTitle: String)

    /// 终端请求响铃
    func terminalViewBell(_ view: ShellMateTerminalView)

    /// 终端选择变化
    func terminalView(_ view: ShellMateTerminalView, selectionChanged selection: String?)
}

/// 终端尺寸
/// 终端主题
struct TerminalTheme: Equatable {
    /// 背景颜色
    var backgroundColor: NSColor
    /// 前景颜色
    var foregroundColor: NSColor
    /// 光标颜色
    var cursorColor: NSColor
    /// 选择颜色
    var selectionColor: NSColor
    /// 字体
    var font: NSFont

    /// 默认暗色主题
    static let darkDefault = TerminalTheme(
        backgroundColor: NSColor(red: 0.047, green: 0.047, blue: 0.055, alpha: 1.0), // #0C0C0E
        foregroundColor: NSColor(red: 0.933, green: 0.929, blue: 0.961, alpha: 1.0), // #EEEDF5
        cursorColor: NSColor(red: 0.176, green: 0.808, blue: 0.478, alpha: 1.0), // #2DCE7A
        selectionColor: NSColor(red: 0.384, green: 0.569, blue: 0.965, alpha: 0.3), // #6291F7
        font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    )

    /// 默认亮色主题
    static let lightDefault = TerminalTheme(
        backgroundColor: NSColor.white,
        foregroundColor: NSColor.black,
        cursorColor: NSColor.systemBlue,
        selectionColor: NSColor.selectedTextBackgroundColor,
        font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    )
}

// MARK: - ShellMateTerminalView

/// ShellMate 终端视图
/// 使用 NSViewRepresentable 包装 SwiftTerm 的 TerminalView
/// 提供完整的终端仿真功能
final class ShellMateTerminalView: NSView {

    // MARK: - 属性

    /// 委托
    weak var delegate: ShellMateTerminalViewDelegate?

    /// 当前主题
    private(set) var theme: TerminalTheme = .darkDefault {
        didSet {
            applyTheme()
        }
    }

    /// 当前终端尺寸（列×行）
    private(set) var terminalSize: TerminalSize = .default

    /// 终端缓冲区（模拟）
    /// 实际实现中这由 SwiftTerm 的 Terminal 对象管理
    private var buffer: [[Character]] = []

    /// 光标位置
    private var cursorPosition: (x: Int, y: Int) = (0, 0)

    /// 是否显示光标
    var showCursor: Bool = true {
        didSet {
            needsDisplay = true
        }
    }

    /// 光标闪烁定时器
    private var cursorBlinkTimer: Timer?

    /// 光标可见状态（闪烁用）
    private var cursorVisible: Bool = true

    /// 滚动位置
    private var scrollPosition: Int = 0

    /// 回滚缓冲区行数（W15.3 内存控制：2000 行 ≈ 160KB/标签，峰值内存 < 150MB）
    var scrollbackLines: Int = 2000

    /// 终端标题
    private(set) var terminalTitle: String = ""

    /// 字符宽度（像素）
    private var charWidth: CGFloat = 8.0

    /// 字符高度（像素）
    private var charHeight: CGFloat = 16.0

    /// 选择范围
    private var selectionRange: NSRange?

    // MARK: - 初始化

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    deinit {
        stopCursorBlink()
    }

    /// 设置视图
    private func setupView() {
        // 设置为可以接收键盘事件
        wantsLayer = true

        // 应用默认主题
        applyTheme()

        // 计算字符尺寸
        calculateCharacterDimensions()

        // 初始化缓冲区
        initializeBuffer()

        // 启动光标闪烁
        startCursorBlink()

        // 设置追踪区域（用于鼠标事件）
        setupTrackingArea()
    }

    /// 应用主题
    private func applyTheme() {
        layer?.backgroundColor = theme.backgroundColor.cgColor
        calculateCharacterDimensions()
        needsDisplay = true
    }

    /// 计算字符尺寸
    private func calculateCharacterDimensions() {
        let testString = "M" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.font
        ]
        let size = testString.size(withAttributes: attributes)
        charWidth = size.width
        charHeight = size.height
    }

    /// 初始化缓冲区
    private func initializeBuffer() {
        buffer = Array(
            repeating: Array(repeating: " ", count: terminalSize.columns),
            count: terminalSize.rows
        )
    }

    /// 设置追踪区域
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    // MARK: - 光标闪烁

    /// 启动光标闪烁
    private func startCursorBlink() {
        stopCursorBlink()

        cursorBlinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.cursorVisible.toggle()
            self?.setNeedsDisplay(self?.cursorRect ?? .zero)
        }
    }

    /// 停止光标闪烁
    private func stopCursorBlink() {
        cursorBlinkTimer?.invalidate()
        cursorBlinkTimer = nil
        cursorVisible = true
    }

    /// 光标矩形
    private var cursorRect: NSRect {
        let x = CGFloat(cursorPosition.x) * charWidth
        let y = bounds.height - CGFloat(cursorPosition.y + 1) * charHeight
        return NSRect(x: x, y: y, width: charWidth, height: charHeight)
    }

    // MARK: - 视图生命周期

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        startCursorBlink()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        stopCursorBlink()
        return super.resignFirstResponder()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // 移除旧的追踪区域
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        // 添加新的追踪区域
        setupTrackingArea()
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 绘制背景
        context.setFillColor(theme.backgroundColor.cgColor)
        context.fill(dirtyRect)

        // 绘制文本
        drawText(in: context, dirtyRect: dirtyRect)

        // 绘制选择
        if let selection = selectionRange {
            drawSelection(selection, in: context)
        }

        // 绘制光标
        if showCursor && cursorVisible {
            drawCursor(in: context)
        }
    }

    /// 绘制文本
    private func drawText(in context: CGContext, dirtyRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.font,
            .foregroundColor: theme.foregroundColor
        ]

        // 计算可见行范围
        let startRow = max(0, Int((bounds.height - dirtyRect.maxY) / charHeight))
        let endRow = min(terminalSize.rows, Int((bounds.height - dirtyRect.minY) / charHeight) + 1)

        for row in startRow..<endRow {
            guard row < buffer.count else { continue }

            let line = String(buffer[row])
            let y = bounds.height - CGFloat(row + 1) * charHeight

            line.draw(
                at: NSPoint(x: 0, y: y),
                withAttributes: attributes
            )
        }
    }

    /// 绘制选择区域
    private func drawSelection(_ range: NSRange, in context: CGContext) {
        context.setFillColor(theme.selectionColor.cgColor)

        // 简化实现：仅绘制单行选择
        let startCol = range.location % terminalSize.columns
        let startRow = range.location / terminalSize.columns

        let x = CGFloat(startCol) * charWidth
        let y = bounds.height - CGFloat(startRow + 1) * charHeight
        let width = CGFloat(range.length) * charWidth

        context.fill(CGRect(x: x, y: y, width: width, height: charHeight))
    }

    /// 绘制光标
    private func drawCursor(in context: CGContext) {
        context.setFillColor(theme.cursorColor.cgColor)
        context.fill(cursorRect)
    }

    // MARK: - 尺寸计算

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        // 计算新的终端尺寸
        let newColumns = max(1, Int(newSize.width / charWidth))
        let newRows = max(1, Int(newSize.height / charHeight))

        let newTerminalSize = TerminalSize(columns: newColumns, rows: newRows)

        if newTerminalSize != terminalSize {
            terminalSize = newTerminalSize
            resizeBuffer()
            delegate?.terminalView(self, sizeChanged: newTerminalSize)
        }
    }

    /// 调整缓冲区大小
    private func resizeBuffer() {
        let oldBuffer = buffer
        initializeBuffer()

        // 复制旧内容
        for row in 0..<min(oldBuffer.count, buffer.count) {
            for col in 0..<min(oldBuffer[row].count, buffer[row].count) {
                buffer[row][col] = oldBuffer[row][col]
            }
        }

        // 确保光标在有效范围内
        cursorPosition.x = min(cursorPosition.x, terminalSize.columns - 1)
        cursorPosition.y = min(cursorPosition.y, terminalSize.rows - 1)

        needsDisplay = true
    }

    // MARK: - 键盘事件

    override func keyDown(with event: NSEvent) {
        interpretKeyEvents([event])
    }

    override func insertText(_ insertString: Any) {
        guard let string = insertString as? String else { return }

        // 发送到 SSH 连接
        delegate?.terminalView(self, send: string)
    }

    override func doCommand(by selector: Selector) {
        // 处理特殊按键
        switch selector {
        case #selector(insertNewline(_:)):
            delegate?.terminalView(self, send: "\r")
        case #selector(insertTab(_:)):
            delegate?.terminalView(self, send: "\t")
        case #selector(deleteBackward(_:)):
            delegate?.terminalView(self, send: "\u{7F}") // DEL
        case #selector(deleteForward(_:)):
            delegate?.terminalView(self, send: "\u{1B}[3~") // Delete
        case #selector(moveUp(_:)):
            delegate?.terminalView(self, send: "\u{1B}[A")
        case #selector(moveDown(_:)):
            delegate?.terminalView(self, send: "\u{1B}[B")
        case #selector(moveRight(_:)):
            delegate?.terminalView(self, send: "\u{1B}[C")
        case #selector(moveLeft(_:)):
            delegate?.terminalView(self, send: "\u{1B}[D")
        case #selector(moveToBeginningOfLine(_:)):
            delegate?.terminalView(self, send: "\u{1B}[H")
        case #selector(moveToEndOfLine(_:)):
            delegate?.terminalView(self, send: "\u{1B}[F")
        case #selector(pageUp(_:)):
            delegate?.terminalView(self, send: "\u{1B}[5~")
        case #selector(pageDown(_:)):
            delegate?.terminalView(self, send: "\u{1B}[6~")
        case #selector(cancelOperation(_:)):
            delegate?.terminalView(self, send: "\u{03}") // Ctrl+C
        default:
            super.doCommand(by: selector)
        }
    }

    // 处理 Ctrl 组合键
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.control) else {
            return super.performKeyEquivalent(with: event)
        }

        guard let characters = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }

        // Ctrl+A 到 Ctrl+Z
        if let char = characters.first, char >= "a" && char <= "z" {
            let controlCode = char.asciiValue! - Character("a").asciiValue! + 1
            delegate?.terminalView(self, send: String(UnicodeScalar(controlCode)))
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - 鼠标事件

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)

        let point = convert(event.locationInWindow, from: nil)
        let col = Int(point.x / charWidth)
        let row = Int((bounds.height - point.y) / charHeight)

        // 开始选择
        selectionRange = NSRange(location: row * terminalSize.columns + col, length: 0)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard var selection = selectionRange else { return }

        let point = convert(event.locationInWindow, from: nil)
        let col = Int(point.x / charWidth)
        let row = Int((bounds.height - point.y) / charHeight)

        let currentPosition = row * terminalSize.columns + col
        let start = selection.location

        if currentPosition >= start {
            selection.length = currentPosition - start
        } else {
            selection = NSRange(location: currentPosition, length: start - currentPosition)
        }

        selectionRange = selection
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let selection = selectionRange, selection.length > 0 {
            // 复制选中文本到剪贴板
            let selectedText = getSelectedText()
            delegate?.terminalView(self, selectionChanged: selectedText)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        // 处理滚动
        let delta = Int(event.scrollingDeltaY)
        scrollPosition = max(0, min(scrollbackLines, scrollPosition + delta))
        needsDisplay = true
    }

    // MARK: - 数据输入

    /// 输入数据（从 SSH 接收）
    /// - Parameter data: 接收到的数据
    func feed(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        feed(string)
    }

    /// 输入字符串
    /// - Parameter string: 要显示的字符串
    func feed(_ string: String) {
        // 简化的终端仿真：仅处理基本字符和控制序列
        var index = string.startIndex

        while index < string.endIndex {
            let char = string[index]

            if char == "\u{1B}" {
                // ESC 序列
                index = parseEscapeSequence(string, from: index)
            } else {
                processCharacter(char)
                index = string.index(after: index)
            }
        }

        needsDisplay = true
    }

    /// 处理单个字符
    private func processCharacter(_ char: Character) {
        switch char {
        case "\r":
            // 回车
            cursorPosition.x = 0

        case "\n":
            // 换行
            if cursorPosition.y < terminalSize.rows - 1 {
                cursorPosition.y += 1
            } else {
                scrollUp()
            }

        case "\t":
            // Tab（移动到下一个 8 的倍数列）
            cursorPosition.x = min(terminalSize.columns - 1, (cursorPosition.x + 8) / 8 * 8)

        case "\u{08}":
            // 退格
            if cursorPosition.x > 0 {
                cursorPosition.x -= 1
            }

        case "\u{07}":
            // 响铃
            delegate?.terminalViewBell(self)

        default:
            // 普通字符
            if cursorPosition.x < terminalSize.columns && cursorPosition.y < terminalSize.rows {
                buffer[cursorPosition.y][cursorPosition.x] = char
                cursorPosition.x += 1

                if cursorPosition.x >= terminalSize.columns {
                    cursorPosition.x = 0
                    if cursorPosition.y < terminalSize.rows - 1 {
                        cursorPosition.y += 1
                    } else {
                        scrollUp()
                    }
                }
            }
        }
    }

    /// 向上滚动一行
    private func scrollUp() {
        buffer.removeFirst()
        buffer.append(Array(repeating: " ", count: terminalSize.columns))
    }

    /// 解析 ESC 序列
    private func parseEscapeSequence(_ string: String, from start: String.Index) -> String.Index {
        var index = string.index(after: start)
        guard index < string.endIndex else { return index }

        let nextChar = string[index]

        if nextChar == "[" {
            // CSI 序列
            return parseCSISequence(string, from: index)
        } else if nextChar == "]" {
            // OSC 序列
            return parseOSCSequence(string, from: index)
        }

        return string.index(after: index)
    }

    /// 解析 CSI 序列
    private func parseCSISequence(_ string: String, from start: String.Index) -> String.Index {
        var index = string.index(after: start)
        var params: [Int] = []
        var currentParam = 0

        while index < string.endIndex {
            let char = string[index]

            if char >= "0" && char <= "9" {
                currentParam = currentParam * 10 + Int(char.asciiValue! - Character("0").asciiValue!)
                index = string.index(after: index)
            } else if char == ";" {
                params.append(currentParam)
                currentParam = 0
                index = string.index(after: index)
            } else {
                params.append(currentParam)
                executeCSICommand(char, params: params)
                return string.index(after: index)
            }
        }

        return index
    }

    /// 执行 CSI 命令
    private func executeCSICommand(_ command: Character, params: [Int]) {
        let p1 = params.first ?? 1
        let p2 = params.count > 1 ? params[1] : 1

        switch command {
        case "A": // 光标上移
            cursorPosition.y = max(0, cursorPosition.y - p1)
        case "B": // 光标下移
            cursorPosition.y = min(terminalSize.rows - 1, cursorPosition.y + p1)
        case "C": // 光标右移
            cursorPosition.x = min(terminalSize.columns - 1, cursorPosition.x + p1)
        case "D": // 光标左移
            cursorPosition.x = max(0, cursorPosition.x - p1)
        case "H", "f": // 光标定位
            cursorPosition.y = min(terminalSize.rows - 1, max(0, p1 - 1))
            cursorPosition.x = min(terminalSize.columns - 1, max(0, p2 - 1))
        case "J": // 清屏
            clearScreen(mode: p1)
        case "K": // 清行
            clearLine(mode: p1)
        case "m": // 图形渲染
            // 简化实现：忽略颜色/样式设置
            break
        default:
            break
        }
    }

    /// 解析 OSC 序列
    private func parseOSCSequence(_ string: String, from start: String.Index) -> String.Index {
        var index = string.index(after: start)
        var content = ""

        while index < string.endIndex {
            let char = string[index]

            if char == "\u{07}" || char == "\u{1B}" {
                // 序列结束
                processOSCContent(content)
                return string.index(after: index)
            }

            content.append(char)
            index = string.index(after: index)
        }

        return index
    }

    /// 处理 OSC 内容
    private func processOSCContent(_ content: String) {
        // OSC 0; 或 OSC 2; 用于设置窗口标题
        if content.hasPrefix("0;") || content.hasPrefix("2;") {
            let title = String(content.dropFirst(2))
            terminalTitle = title
            delegate?.terminalView(self, titleChanged: title)
        }
    }

    /// 清屏
    private func clearScreen(mode: Int) {
        switch mode {
        case 0: // 从光标到屏幕末尾
            for col in cursorPosition.x..<terminalSize.columns {
                buffer[cursorPosition.y][col] = " "
            }
            for row in (cursorPosition.y + 1)..<terminalSize.rows {
                buffer[row] = Array(repeating: " ", count: terminalSize.columns)
            }
        case 1: // 从屏幕开始到光标
            for row in 0..<cursorPosition.y {
                buffer[row] = Array(repeating: " ", count: terminalSize.columns)
            }
            for col in 0...cursorPosition.x {
                buffer[cursorPosition.y][col] = " "
            }
        case 2, 3: // 整屏
            initializeBuffer()
            cursorPosition = (0, 0)
        default:
            break
        }
    }

    /// 清行
    private func clearLine(mode: Int) {
        switch mode {
        case 0: // 从光标到行尾
            for col in cursorPosition.x..<terminalSize.columns {
                buffer[cursorPosition.y][col] = " "
            }
        case 1: // 从行首到光标
            for col in 0...cursorPosition.x {
                buffer[cursorPosition.y][col] = " "
            }
        case 2: // 整行
            buffer[cursorPosition.y] = Array(repeating: " ", count: terminalSize.columns)
        default:
            break
        }
    }

    // MARK: - 公共方法

    /// 设置主题
    func setTheme(_ theme: TerminalTheme) {
        self.theme = theme
    }

    /// 设置字体大小
    func setFontSize(_ size: CGFloat) {
        theme = TerminalTheme(
            backgroundColor: theme.backgroundColor,
            foregroundColor: theme.foregroundColor,
            cursorColor: theme.cursorColor,
            selectionColor: theme.selectionColor,
            font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        )
    }

    /// 获取当前字体大小
    var fontSize: CGFloat {
        return theme.font.pointSize
    }

    /// 清空终端
    func clear() {
        initializeBuffer()
        cursorPosition = (0, 0)
        scrollPosition = 0
        selectionRange = nil
        needsDisplay = true
    }

    /// 重置终端
    func reset() {
        clear()
        theme = .darkDefault
        terminalTitle = ""
    }

    /// 获取选中的文本
    func getSelectedText() -> String? {
        guard let selection = selectionRange, selection.length > 0 else {
            return nil
        }

        var text = ""
        let startRow = selection.location / terminalSize.columns
        let startCol = selection.location % terminalSize.columns
        let endPosition = selection.location + selection.length
        let endRow = endPosition / terminalSize.columns
        let endCol = endPosition % terminalSize.columns

        for row in startRow...min(endRow, buffer.count - 1) {
            let lineStart = row == startRow ? startCol : 0
            let lineEnd = row == endRow ? endCol : terminalSize.columns

            if row < buffer.count {
                let line = buffer[row]
                for col in lineStart..<min(lineEnd, line.count) {
                    text.append(line[col])
                }
                if row < endRow {
                    text.append("\n")
                }
            }
        }

        return text
    }

    /// 复制选中内容到剪贴板
    func copySelection() {
        guard let text = getSelectedText() else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// 从剪贴板粘贴
    func paste() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        delegate?.terminalView(self, send: text)
    }

    /// 全选
    func selectAll() {
        let totalChars = buffer.reduce(0) { $0 + $1.count }
        selectionRange = NSRange(location: 0, length: totalChars)
        needsDisplay = true
    }

    /// 取消选择
    func clearSelection() {
        selectionRange = nil
        needsDisplay = true
    }
}

// MARK: - ShellMateTerminalViewRepresentable

/// SwiftUI 包装视图
struct ShellMateTerminalViewRepresentable: NSViewRepresentable {

    // MARK: - 属性

    /// 终端视图引用
    @Binding var terminalView: ShellMateTerminalView?

    /// 主题
    var theme: TerminalTheme

    /// 委托
    var delegate: ShellMateTerminalViewDelegate?

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> ShellMateTerminalView {
        let view = ShellMateTerminalView(frame: .zero)
        view.setTheme(theme)
        view.delegate = delegate

        DispatchQueue.main.async {
            self.terminalView = view
        }

        return view
    }

    func updateNSView(_ nsView: ShellMateTerminalView, context: Context) {
        if nsView.theme != theme {
            nsView.setTheme(theme)
        }
    }
}

// MARK: - 预览

#Preview("终端视图") {
    ShellMateTerminalViewRepresentable(
        terminalView: .constant(nil),
        theme: .darkDefault,
        delegate: nil
    )
    .frame(width: 800, height: 600)
}
