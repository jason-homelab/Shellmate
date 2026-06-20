import SwiftUI

// MARK: - 环境变量条目（表单内 Identifiable 包装）

struct EnvVarEntry: Identifiable {
    var id: UUID = UUID()
    var key: String
    var value: String
}

// MARK: - 高级设置 Tab（D01 Tab 3）

/// 会话高级设置 Tab
/// 包含跳板机 ProxyJump、自动重连、Keep-Alive、连接超时、环境变量
struct SessionAdvancedTab: View {

    // MARK: - 属性

    @Binding var proxyJump: String
    @Binding var autoReconnect: Bool
    @Binding var maxReconnectRetries: Int32
    @Binding var reconnectInterval: Int32
    /// keepAliveInterval == 0 表示禁用，> 0 表示启用并为秒数
    @Binding var keepAliveInterval: Int32
    @Binding var connectTimeout: Int32
    @Binding var envVarEntries: [EnvVarEntry]
    @Binding var tmuxConfig: TmuxConfig

    // MARK: - 私有状态

    /// 用于 Keep-Alive 关闭时记住上次间隔值
    @State private var lastKeepAliveInterval: Int32 = 60

    // MARK: - 计算属性

    private var keepAliveEnabled: Bool {
        keepAliveInterval > 0
    }

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                proxyJumpSection
                    .padding(.bottom, 14)

                Divider().padding(.bottom, 14)

                reconnectSection
                    .padding(.bottom, 14)

                Divider().padding(.bottom, 14)

                keepAliveSection
                    .padding(.bottom, 14)

                Divider().padding(.bottom, 14)

                timeoutSection
                    .padding(.bottom, 14)

                Divider().padding(.bottom, 14)

                envVarsSection
                    .padding(.bottom, 14)

                Divider().padding(.bottom, 14)

                tmuxSection
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    // MARK: - 跳板机

    private var proxyJumpSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            sectionLabel("跳板机（ProxyJump）")

            CustomTextField(placeholder: "user@jump-host.example.com:22", text: $proxyJump)

            Text("多跳板机用英文逗号分隔，如 user@host1,user@host2")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
    }

    // MARK: - 自动重连

    private var reconnectSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Toggle(isOn: $autoReconnect) {
                Text("断连后自动重连")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .toggleStyle(.switch)

            if autoReconnect {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    subOptionRow(label: "最大重试次数", unit: "次") {
                        int32StepperField($maxReconnectRetries, range: 1...20)
                    }
                    subOptionRow(label: "重试间隔", unit: "秒") {
                        int32StepperField($reconnectInterval, range: 1...60)
                    }
                }
                .padding(.leading, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(DesignTokens.Animation.fast, value: autoReconnect)
    }

    // MARK: - Keep-Alive

    private var keepAliveSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Toggle(isOn: Binding(
                get: { keepAliveInterval > 0 },
                set: { enabled in
                    if enabled {
                        keepAliveInterval = lastKeepAliveInterval > 0 ? lastKeepAliveInterval : 60
                    } else {
                        lastKeepAliveInterval = keepAliveInterval
                        keepAliveInterval = 0
                    }
                }
            )) {
                Text("发送 Keep-Alive 心跳包")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .toggleStyle(.switch)

            if keepAliveEnabled {
                subOptionRow(label: "心跳间隔", unit: "秒") {
                    int32StepperField(Binding(
                        get: { keepAliveInterval > 0 ? keepAliveInterval : 60 },
                        set: { keepAliveInterval = $0 }
                    ), range: 10...300, step: 10)
                }
                .padding(.leading, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(DesignTokens.Animation.fast, value: keepAliveEnabled)
    }

    // MARK: - 连接超时

    private var timeoutSection: some View {
        subOptionRow(label: "连接超时", unit: "秒") {
            int32StepperField($connectTimeout, range: 5...120, step: 5)
        }
    }

    // MARK: - 环境变量

    private var envVarsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                sectionLabel("环境变量")
                Spacer()
                Button(action: {
                    withAnimation(DesignTokens.Animation.fast) {
                        envVarEntries.append(EnvVarEntry(key: "", value: ""))
                    }
                }) {
                    Label("添加", systemImage: "plus")
                        .font(DesignTokens.Typography.captionMedium)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if envVarEntries.isEmpty {
                Text("暂无环境变量")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textDisabled)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignTokens.Spacing.sm)
            } else {
                VStack(spacing: DesignTokens.Spacing.xxs) {
                    ForEach($envVarEntries) { $entry in
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            CustomTextField(placeholder: "KEY", text: $entry.key)
                                .frame(maxWidth: .infinity)

                            Text("=")
                                .font(DesignTokens.Typography.captionMedium)
                                .foregroundColor(DesignTokens.Colors.textDisabled)

                            CustomTextField(placeholder: "value", text: $entry.value)
                                .frame(maxWidth: .infinity)

                            Button(action: {
                                withAnimation(DesignTokens.Animation.fast) {
                                    envVarEntries.removeAll { $0.id == entry.id }
                                }
                            }) {
                                AppIcon.close.image
                                    .font(DesignTokens.Typography.captionMedium)
                                    .foregroundColor(DesignTokens.Colors.textDisabled)
                            }
                            .buttonStyle(.plain)
                            .help("删除此环境变量")
                        }
                    }
                }
            }
        }
    }

    // MARK: - tmux 集成

    private var tmuxSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                AppIcon.tmux.image
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                sectionLabel("tmux 集成")
            }

            Toggle(isOn: $tmuxConfig.enabled) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text("连接后自动检测 tmux")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Text("SSH 连接建立后自动检查 tmux 可用性及已有会话列表")
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                }
            }
            .toggleStyle(.switch)

            if tmuxConfig.enabled {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // 自动附加策略
                    HStack(spacing: 10) {
                        Text("自动附加")
                            .frame(width: 80, alignment: .leading)
                            .font(DesignTokens.Typography.captionLarge)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Picker("", selection: $tmuxConfig.autoAttach) {
                            ForEach(TmuxAutoAttach.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 240)
                    }

                    // 指定会话名（.named 策略时显示）
                    if tmuxConfig.autoAttach == .named {
                        HStack(spacing: 10) {
                            Text("会话名")
                                .frame(width: 80, alignment: .leading)
                                .font(DesignTokens.Typography.captionLarge)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            CustomTextField(placeholder: "例如: dev", text: $tmuxConfig.sessionName)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 新建会话名（.create 策略时显示）
                    if tmuxConfig.autoAttach == .create {
                        HStack(spacing: 10) {
                            Text("新会话名")
                                .frame(width: 80, alignment: .leading)
                                .font(DesignTokens.Typography.captionLarge)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            CustomTextField(placeholder: "留空则使用默认编号", text: $tmuxConfig.newSessionName)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // 断开时行为
                    HStack(spacing: 10) {
                        Text("SSH 断开时")
                            .frame(width: 80, alignment: .leading)
                            .font(DesignTokens.Typography.captionLarge)
                            .foregroundColor(DesignTokens.Colors.textSecondary)

                        Picker("", selection: $tmuxConfig.disconnectBehavior) {
                            ForEach(TmuxDisconnectBehavior.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 240)
                    }

                    // 有会话时自动弹出管理器
                    Toggle(isOn: $tmuxConfig.autoShowManager) {
                        Text("有会话时自动显示管理器")
                            .font(DesignTokens.Typography.captionLarge)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    .toggleStyle(.switch)
                }
                .padding(.leading, 14)
                .animation(DesignTokens.Animation.fast, value: tmuxConfig.autoAttach)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(DesignTokens.Animation.fast, value: tmuxConfig.enabled)
    }

    // MARK: - 辅助组件

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Typography.labelSmall)
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .textCase(.uppercase)
            .kerning(0.4)
    }

    @ViewBuilder
    private func subOptionRow<Content: View>(
        label: String,
        unit: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .frame(width: 120, alignment: .leading)
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            content()

            Text(unit)
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
    }

    /// 数字输入框 + 步进器组合，与 Int32 Binding 配合
    private func int32StepperField(
        _ value: Binding<Int32>,
        range: ClosedRange<Int32>,
        step: Int32 = 1
    ) -> some View {
        // Stepper 需要 Int（Strideable），使用 Int Binding 做桥接
        let intBinding = Binding<Int>(
            get: { Int(value.wrappedValue) },
            set: { value.wrappedValue = Int32(clamping: $0) }
        )
        let intRange = Int(range.lowerBound)...Int(range.upperBound)
        let intStep  = Int(step)

        return HStack(spacing: 0) {
            TextField("", text: Binding(
                get: { String(value.wrappedValue) },
                set: { text in
                    if let n = Int32(text), range.contains(n) {
                        value.wrappedValue = n
                    }
                }
            ))
            .textFieldStyle(.plain)
            .frame(width: 52)
            .multilineTextAlignment(.center)
            .font(DesignTokens.Typography.codeTiny)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )

            Stepper("", value: intBinding, in: intRange, step: intStep)
                .labelsHidden()
        }
    }
}

// MARK: - 预览

#Preview("高级设置 Tab") {
    SessionAdvancedTab(
        proxyJump: .constant(""),
        autoReconnect: .constant(true),
        maxReconnectRetries: .constant(3),
        reconnectInterval: .constant(5),
        keepAliveInterval: .constant(60),
        connectTimeout: .constant(30),
        envVarEntries: .constant([
            EnvVarEntry(key: "TERM", value: "xterm-256color"),
            EnvVarEntry(key: "LANG", value: "en_US.UTF-8")
        ]),
        tmuxConfig: .constant(TmuxConfig())
    )
    .frame(width: 504, height: 460)
    .background(DesignTokens.Colors.surfacePanel)
}
