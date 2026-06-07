import SwiftUI

// W4 新增：统一 Loading 形态分级（解 UE-P1#15 骨架屏）
// 详见 docs/design-specs/W0_设计规格统一交付.md §5

enum LoadingPresentation {
    case skeleton(rows: Int, style: SkeletonStyle)
    case shimmer(layout: ShimmerLayout)
    case spinner(label: LocalizedStringKey?)
    case progress(percent: Double, label: LocalizedStringKey)
    case inline(text: LocalizedStringKey)

    enum SkeletonStyle {
        case sidebarRow
        case fileRow
        case messageCard
        case settingsRow
    }

    enum ShimmerLayout {
        case card
        case banner
        case avatar
    }
}

// MARK: - 状态枚举

enum LoadStatus<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(Error)

    var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }
}

// MARK: - LoadingContainer

struct LoadingContainer<Value, Content: View, EmptyContent: View>: View {

    let status: LoadStatus<Value>
    let presentation: LoadingPresentation
    let content: (Value) -> Content
    let emptyContent: () -> EmptyContent

    init(
        status: LoadStatus<Value>,
        presentation: LoadingPresentation,
        @ViewBuilder content: @escaping (Value) -> Content,
        @ViewBuilder empty: @escaping () -> EmptyContent = { EmptyView() }
    ) {
        self.status = status
        self.presentation = presentation
        self.content = content
        self.emptyContent = empty
    }

    var body: some View {
        switch status {
        case .idle:
            emptyContent()
        case .loading:
            LoadingView(presentation: presentation)
        case .loaded(let value):
            content(value)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .failed:
            emptyContent()
        }
    }
}

// MARK: - LoadingView 分发

struct LoadingView: View {
    let presentation: LoadingPresentation

    var body: some View {
        switch presentation {
        case .skeleton(let rows, let style):
            SkeletonList(rowCount: rows, style: style)
        case .shimmer(let layout):
            ShimmerCard(layout: layout)
        case .spinner(let label):
            VStack(spacing: DesignTokens.Spacing.xs) {
                ProgressView()
                if let label = label {
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .progress(let percent, let label):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                ProgressView(value: percent)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding()
        case .inline(let text):
            HStack(spacing: DesignTokens.Spacing.xxs) {
                ProgressView().controlSize(.small)
                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}
