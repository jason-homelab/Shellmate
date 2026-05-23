import SwiftUI

// MARK: - 录制对话框（Figma-Spec-v2 §14 §6）

/// 终端会话录制对话框 — 三状态：就绪 / 录制中 / 回顾
/// sm:max-w-2xl ≈ 672pt，对齐 Figma-Spec-v2 更新后规范
struct RecordingDialogView: View {

    // MARK: - 录制阶段

    enum RecordingPhase: Equatable {
        case ready
        case recording
        case review
    }

    // MARK: - 属性

    /// 当前活跃的会话名称（由调用方传入）
    let sessionName: String
    /// 由 TerminalController 提供的录制器（每个 Tab 独立实例）
    let recorder: SessionRecorder
    var onClose: () -> Void

    // MARK: - 状态

    @State private var recordingPhase: RecordingPhase = .ready
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var elapsedTimer: Timer?

    /// 回顾阶段：上次录制的元数据
    @State private var reviewDuration: TimeInterval = 0
    @State private var reviewFilename: String = ""
    @State private var reviewFileSize: Int64 = 0

    /// 历史录制文件
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
            switch recordingPhase {
            case .ready:
                readyStateView
                if !recordings.isEmpty {
                    Divider()
                    recordingsListSection
                }
            case .recording:
                recordingStateView
            case .review:
                reviewStateView
            }
            if let error = saveError {
                Text(error)
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.xs)
            }
            Divider()
            footerView
        }
        // Figma 20:2: 460px white card, rounded-2xl, shadow
        .frame(width: 460)
        .frame(minHeight: 340, maxHeight: 560)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
        .onAppear {
            loadRecordings()
            // 同步录制器当前状态（面板关闭后重新打开时，录制可能仍在进行）
            Task {
                let recording = await recorder.isRecording
                let elapsed   = await recorder.elapsedSeconds
                await MainActor.run {
                    if recording && recordingPhase == .ready {
                        recordingPhase = .recording
                        startTimer(resumingFrom: elapsed)
                    }
                }
            }
        }
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
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [DesignTokens.Colors.statusError, DesignTokens.Colors.statusError],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                    .shadow(color: DesignTokens.Colors.statusError.opacity(0.35), radius: 6, x: 0, y: 3)
                Image(systemName: "record.circle")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.px) {
                Text("终端录制")
                    .font(DesignTokens.Typography.bodyLargeStrong)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("录制终端操作并保存为 asciinema v2 格式")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 14)
    }

    // MARK: - 就绪状态

    private var readyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.statusError.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: "record.circle")
                    .font(DesignTokens.Typography.displayLarge)
                    .foregroundColor(DesignTokens.Colors.statusError)
            }

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("准备录制")
                    .font(DesignTokens.Typography.labelLargeAlt)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("将捕获当前终端会话的所有输入输出，保存为 asciinema v2 格式")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                if !sessionName.isEmpty {
                    Text("会话：\(sessionName)")
                        .font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Button {
                startRecording()
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "record.circle.fill")
                        .font(DesignTokens.Typography.titleSmall)
                    Text("开始录制")
                        .font(DesignTokens.Typography.titleSmall)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, 9)
                .background(DesignTokens.Colors.statusError)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(color: DesignTokens.Colors.statusError.opacity(0.30), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(sessionName.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xl)
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }

    // MARK: - 录制中状态

    private var recordingStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // 录制指示灯
            HStack(spacing: DesignTokens.Spacing.sm) {
                Circle()
                    .fill(DesignTokens.Colors.statusError)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(DesignTokens.Colors.statusError.opacity(0.35), lineWidth: 2)
                            .scaleEffect(1.6)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: recordingPhase
                            )
                    )
                Text("录制中")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.statusError)
            }

            // 大计时器
            Text(elapsedFormatted)
                .font(DesignTokens.Typography.heroXLarge)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .monospacedDigit()

            if !sessionName.isEmpty {
                Text("会话：\(sessionName)")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Button {
                stopRecording()
            } label: {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "stop.fill")
                        .font(DesignTokens.Typography.bodySmallStrong)
                    Text("停止录制")
                        .font(DesignTokens.Typography.titleSmall)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, 9)
                .background(DesignTokens.Colors.statusError)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xl)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.statusError.opacity(0.03))
    }

    // MARK: - 回顾状态

    private var reviewStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // 深色预览块（#1e1e1e 背景）
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DesignTokens.Typography.bodyLargeMedium)
                        .foregroundColor(DesignTokens.Colors.statusConnected)
                    Text("录制完成")
                        .font(DesignTokens.Typography.titleSmall)
                        .foregroundColor(.white)
                    Spacer()
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.15))

                HStack(spacing: DesignTokens.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.nano) {
                        Text("时长")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(Color.white.opacity(0.50))
                        Text(durationFormatted(reviewDuration))
                            .font(DesignTokens.Typography.labelLarge)
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.nano) {
                        Text("文件大小")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(Color.white.opacity(0.50))
                        Text(fileSizeFormatted(reviewFileSize))
                            .font(DesignTokens.Typography.labelLarge)
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.nano) {
                        Text("文件名")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(Color.white.opacity(0.50))
                        Text(reviewFilename.isEmpty ? "—" : reviewFilename)
                            .font(DesignTokens.Typography.codeTiny)
                            .foregroundColor(Color.white.opacity(0.80))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.terminalPreviewBg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 操作按钮行
            HStack(spacing: DesignTokens.Spacing.sm) {
                // 重录（outline 按钮）
                Button {
                    elapsedSeconds = 0
                    saveError = nil
                    recordingPhase = .ready
                    loadRecordings()
                } label: {
                    Text("重录")
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                // 完成（blue 按钮）
                Button {
                    onClose()
                } label: {
                    Text("完成")
                        .font(DesignTokens.Typography.titleSmall)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(DesignTokens.Colors.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.lg)
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }

    // MARK: - 历史录制文件列表

    private var recordingsListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("历史录制")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Spacer()
                Text("\(recordings.count) 个文件")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, 10)
            .padding(.bottom, DesignTokens.Spacing.xs)

            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.xxs) {
                    ForEach(recordings) { recording in
                        recordingRow(recording)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.sm)
            }
            .frame(maxHeight: 200)
        }
    }

    private func recordingRow(_ recording: RecordingFile) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(DesignTokens.Colors.statusError.opacity(0.08))
                    .frame(width: 28, height: 28)
                Image(systemName: "play.rectangle")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.statusError)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(recording.sessionName)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(recording.createdAt, style: .date)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    if recording.fileSize > 0 {
                        Text(fileSizeFormatted(recording.fileSize))
                            .font(DesignTokens.Typography.codeTiny)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    if recording.duration > 0 {
                        Text(durationFormatted(recording.duration))
                            .font(DesignTokens.Typography.codeTiny)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Button {
                    RecordingStorage.revealInFinder(filename: recording.filename)
                } label: {
                    Image(systemName: "folder")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("在 Finder 中显示")

                Button {
                    pendingDeleteFilename = recording.filename
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("删除录制文件")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, DesignTokens.Spacing.sm)
        // Figma 20:10: bg-white border-[rgba(0,0,0,0.06)] rounded-[8px]
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - 底部

    private var footerView: some View {
        HStack {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Image(systemName: "folder")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text("~/Documents/ShellMate/Recordings/")
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            Spacer()
            Button("打开文件夹") {
                let url = RecordingStorage.recordingsDirectory
                try? RecordingStorage.ensureDirectoryExists()
                NSWorkspace.shared.open(url)
            }
            .font(DesignTokens.Typography.captionLarge)
            .buttonStyle(.borderless)
            .foregroundColor(DesignTokens.Colors.accentPrimary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 10)
    }

    // MARK: - 录制操作

    private func startRecording() {
        Task {
            await recorder.startRecording(sessionName: sessionName)
            await MainActor.run {
                recordingPhase = .recording
                startTimer()
            }
        }
    }

    private func stopRecording() {
        stopTimer()
        isSaving = true

        Task {
            guard let result = await recorder.stopRecording() else {
                await MainActor.run {
                    isSaving = false
                    recordingPhase = .ready
                }
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
                    reviewDuration = result.duration
                    reviewFilename = file.filename
                    reviewFileSize = file.fileSize
                    recordings.insert(file, at: 0)
                    recordingPhase = .review
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = "保存失败：\(error.localizedDescription)"
                    recordingPhase = .ready
                }
            }
        }
    }

    private func startTimer(resumingFrom offset: TimeInterval = 0) {
        elapsedSeconds = offset
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

    private func durationFormatted(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return m > 0 ? "\(m)m\(s)s" : "\(s)s"
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let recordingStarted = Notification.Name("app.shellmate.recordingStarted")
    static let recordingStopped = Notification.Name("app.shellmate.recordingStopped")
}
