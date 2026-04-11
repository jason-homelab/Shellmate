import SwiftUI

// MARK: - AI 助手设置面板（S06）

struct AISettingsView: View {

    @ObservedObject private var store = AISettingsStore.shared

    @State private var apiKeyInput: String = ""
    @State private var showAPIKey: Bool = false
    @State private var isSavingKey: Bool = false
    @State private var saveKeyResult: SaveResult? = nil

    enum SaveResult { case success, empty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 启用开关
                enableSection

                if store.isEnabled {
                    Divider().opacity(0.5)
                    providerSection
                    Divider().opacity(0.5)
                    apiKeySection
                    Divider().opacity(0.5)
                    modelSection
                    Divider().opacity(0.5)
                    featuresSection
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .onAppear {
            apiKeyInput = store.loadAPIKey(for: store.provider)
        }
        .onChange(of: store.providerRaw) { _ in
            apiKeyInput = store.loadAPIKey(for: store.provider)
            saveKeyResult = nil
        }
    }

    // MARK: - 启用开关

    private var enableSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Label("AI 助手", systemImage: "sparkles")
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("在终端工具栏启用 AI 辅助功能，支持命令解释、错误分析和自然语言指令")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $store.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    // MARK: - 提供商选择

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            sectionHeader("AI 提供商", icon: "server.rack")

            VStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(AIProvider.allCases, id: \.rawValue) { prov in
                    providerRow(prov)
                }
            }
        }
    }

    private func providerRow(_ prov: AIProvider) -> some View {
        let isSelected = store.provider == prov
        return Button {
            store.provider = prov
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 选中指示
                Circle()
                    .fill(isSelected ? DesignTokens.Colors.accentPrimary : Color.clear)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().strokeBorder(
                            isSelected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.borderPrimary,
                            lineWidth: 1.5
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(prov.displayName)
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text(providerDescription(prov))
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                Spacer()
                if !prov.needsAPIKey {
                    Text("无需 API Key")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.statusConnected)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(DesignTokens.Colors.statusConnected.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous))
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                isSelected
                    ? DesignTokens.Colors.accentPrimary.opacity(0.08)
                    : DesignTokens.Colors.glassMedium
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? DesignTokens.Colors.accentPrimary.opacity(0.30)
                            : DesignTokens.Colors.glassBorderSide,
                        lineWidth: isSelected ? 1.0 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func providerDescription(_ prov: AIProvider) -> String {
        switch prov {
        case .claude:  return "Anthropic Claude — 优秀的代码与指令理解能力"
        case .openAI:  return "OpenAI GPT — 最广泛使用的 AI 平台"
        case .ollama:  return "本地运行 — 数据不出境，适合隐私敏感场景"
        }
    }

    // MARK: - API Key

    @ViewBuilder
    private var apiKeySection: some View {
        if store.provider.needsAPIKey {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                sectionHeader("API Key", icon: "key.fill")

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Group {
                        if showAPIKey {
                            TextField("sk-...", text: $apiKeyInput)
                        } else {
                            SecureField("sk-...", text: $apiKeyInput)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
                    )

                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help(showAPIKey ? "隐藏 API Key" : "显示 API Key")

                    Button {
                        let keyToSave = apiKeyInput
                        store.saveAPIKey(keyToSave, for: store.provider)
                        // 保存后立即清零 @State 内存中的明文 API Key
                        apiKeyInput.removeAll(keepingCapacity: false)
                        withAnimation { saveKeyResult = keyToSave.isEmpty ? .empty : .success }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { saveKeyResult = nil }
                        }
                    } label: {
                        Text("保存")
                            .font(DesignTokens.Typography.labelMedium)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(DesignTokens.Colors.accentPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                // 保存结果提示
                if let result = saveKeyResult {
                    HStack(spacing: 4) {
                        Image(systemName: result == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(result == .success ? "API Key 已安全存入 Keychain" : "API Key 为空，已清除")
                    }
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(result == .success
                        ? DesignTokens.Colors.statusConnected
                        : DesignTokens.Colors.textTertiary)
                }

                // 获取 Key 链接提示
                Text(apiKeyHint)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
    }

    private var apiKeyHint: String {
        switch store.provider {
        case .claude:  return "在 console.anthropic.com 获取 API Key"
        case .openAI:  return "在 platform.openai.com/api-keys 获取 API Key"
        case .ollama:  return ""
        }
    }

    // MARK: - 模型选择

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if store.provider == .ollama {
                sectionHeader("Ollama 服务地址", icon: "network")
                HStack {
                    TextField("http://localhost:11434", text: $store.ollamaBaseURL)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .padding(DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.surfaceInput)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
                        )
                    Spacer()
                }
                Text("请确保 Ollama 已启动（ollama serve）")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            sectionHeader("模型选择", icon: "cpu")

            Picker("", selection: $store.modelId) {
                ForEach(store.provider.models) { model in
                    Text(model.name).tag(model.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - 功能开关

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            sectionHeader("功能开关", icon: "slider.horizontal.3")

            featureToggle(
                title: "错误侦探",
                subtitle: "自动检测终端错误并显示 AI 分析入口",
                icon: "exclamationmark.triangle",
                binding: $store.errorDetectiveEnabled
            )
        }
    }

    private func featureToggle(title: String, subtitle: String, icon: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(subtitle)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.glassMedium)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
    }

    // MARK: - 辅助

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(DesignTokens.Colors.textSecondary)
    }
}

// MARK: - 预览

#Preview("AI 设置") {
    AISettingsView()
        .frame(width: 480, height: 520)
        .background(DesignTokens.Colors.surfaceWindow)
}
