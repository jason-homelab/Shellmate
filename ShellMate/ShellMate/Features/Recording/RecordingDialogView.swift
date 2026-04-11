import SwiftUI

// MARK: - 录制对话框（Figma-Spec-v2 §14 §6）

/// 终端会话录制对话框
/// 支持启动/停止录制、查看历史录制文件、在 Finder 中打开、删除
struct RecordingDialogView: View {

    // MARK: - 属性

    /// 当前活跃的会话名称（由调用方传入）
    let sessionName: String
    var onClose: () -> Void

    // MARK: - 录制状态

    @State private var recorder = SessionRecorder()
    @State private var isRecording = false
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var elapsedTimer: Timer?

    // MARK: - 录制文件列表

    @State private var recordings: [RecordingFile] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var pendingDeleteFilename: String?
    @State private var showDeleteConfirm = false

    // MARK: - 计时器格式

    private var elapsedFormatted: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            recordingControlSection
            Divider()
            recordingsListSection
            if let error = saveError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, 6)
            }
            Divider()
            footerView
        }
        .frame(width: 500)
        .frame(minHeight: 380, maxHeight: 600)
        .background(Color.white.opacity(0.95))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
        .onAppear { loadRecordings() }
        .onDisappear { stopTimer() }
        .confirmationDialog("删除录制", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let fn = pendingDeleteFilename {
                    try? RecordingStorage.delete(filename: fn)
                    loadRecordings()
                    pendingDeleteFilename = nil
                }
            }
            Button("取消", role: .cancel) { pendingDeleteFilename = nil }
        } message: {
            Text("此操作无法撤销，录制文件将被永久删除。")
        }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: 10) {
            // 录制图标（红色渐变，对齐 Figma §6）
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#ff3b30"), Color(hex: "#ff2d55")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                    .shadow(color: Color(hex: "#ff3b30").opacity(0.35), radius: 6, x: 0, y: 3)
                Image(systemName: "record.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("终端录制")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("录制终端操作并保存为 asciinema v2 格式")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
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

    // MARK: - 录制控制区

    private var recordingControlSection: some View {
        HStack(spacing: 16) {
            // 状态指示灯
            HStack(spacing: 8) {
                Circle()
                    .fill(isRecording ? Color(hex: "#ff3b30") : Color(hex: "#c7c7cc"))
                    .frame(width: 10, height: 10)
                    .overlay(
                        // 录制中的脉冲动画
                        isRecording ?
                        Circle()
                            .stroke(Color(hex: "#ff3b30").opacity(0.4), lineWidth: 2)
                            .scaleEffect(1.6)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
                        : nil
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(isRecording ? "录制中" : "已就绪")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isRecording ? Color(hex: "#ff3b30") : DesignTokens.Colors.textPrimary)
                    if isRecording {
                        Text(elapsedFormatted)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    } else {
                        Text("会话：\(sessionName.isEmpty ? "未选中" : sessionName)")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 开始/停止按钮
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isRecording ? "stop.fill" : "record.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(isRecording ? "停止录制" : "开始录制")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isRecording ? Color(hex: "#ff3b30") : DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(sessionName.isEmpty && !isRecording)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 14)
        .background(isRecording
            ? Color(hex: "#ff3b30").opacity(0.04)
            : DesignTokens.Colors.surfaceCard)
    }

    // MARK: - 录制文件列表

    private var recordingsListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("历史录制")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Spacer()
                Text("\(recordings.count) 个文件")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if recordings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text("暂无录制文件")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(recordings) { recording in
                            recordingRow(recording)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func recordingRow(_ recording: RecordingFile) -> some View {
        HStack(spacing: 10) {
            // 文件图标
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: "#ff3b30").opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: "play.rectangle")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#ff3b30"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.sessionName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(recording.createdAt, style: .date)
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    if recording.fileSize > 0 {
                        Text(fileSizeFormatted(recording.fileSize))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 2) {
                // Finder 中显示
                Button {
                    RecordingStorage.revealInFinder(filename: recording.filename)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("在 Finder 中显示")

                // 删除
                Button {
                    pendingDeleteFilename = recording.filename
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("删除录制文件")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.40), lineWidth: 0.5)
        )
    }

    // MARK: - 底部

    private var footerView: some View {
        HStack {
            // 存储位置提示
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text("~/Documents/ShellMate/Recordings/")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            Spacer()
            Button("打开文件夹") {
                let url = RecordingStorage.recordingsDirectory
                try? RecordingStorage.ensureDirectoryExists()
                NSWorkspace.shared.open(url)
            }
            .font(.system(size: 11))
            .buttonStyle(.borderless)
            .foregroundColor(DesignTokens.Colors.accentPrimary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 10)
    }

    // MARK: - 操作

    private func startRecording() {
        Task {
            await recorder.startRecording(sessionName: sessionName)
            await MainActor.run {
                isRecording = true
                startTimer()
                // 发送通知，让 TerminalView 开始向 recorder 推送数据
                NotificationCenter.default.post(
                    name: .recordingStarted,
                    object: nil,
                    userInfo: ["sessionName": sessionName]
                )
            }
        }
    }

    private func stopRecording() {
        stopTimer()
        isRecording = false
        isSaving = true

        Task {
            guard let result = await recorder.stopRecording() else {
                await MainActor.run { isSaving = false }
                return
            }

            do {
                let name = await recorder.sessionName
                let file = try RecordingStorage.save(
                    data: result.content,
                    sessionName: name,
                    duration: result.duration
                )
                await MainActor.run {
                    isSaving = false
                    recordings.insert(file, at: 0)
                    NotificationCenter.default.post(name: .recordingStopped, object: nil)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = "保存失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func startTimer() {
        elapsedSeconds = 0
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func loadRecordings() {
        Task.detached(priority: .userInitiated) {
            let files = RecordingStorage.listRecordings()
            await MainActor.run { recordings = files }
        }
    }

    private func fileSizeFormatted(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let recordingStarted = Notification.Name("app.shellmate.recordingStarted")
    static let recordingStopped = Notification.Name("app.shellmate.recordingStopped")
}

// MARK: - 预览

#Preview("录制对话框") {
    RecordingDialogView(sessionName: "ubuntu@192.168.1.1", onClose: {})
        .padding()
}
