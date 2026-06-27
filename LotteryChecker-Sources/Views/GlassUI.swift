import SwiftUI
import LotteryKit

struct PageScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content()
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .background(.regularMaterial)
    }
}

struct GlassPanel<Content: View>: View {
    var spacing: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        GlassPanel(spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .contentTransition(.numericText())
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint.opacity(0.72))
                .padding(16)
        }
    }
}

struct StatusBanner: View {
    let text: String

    private var isError: Bool {
        text.hasPrefix("错误") || text.hasPrefix("该期") || text.contains("失败")
    }

    var body: some View {
        if !text.isEmpty {
            Label(text, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(isError ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "tray"

    var body: some View {
        GlassPanel(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

extension Category {
    var symbolName: String {
        switch self {
        case .ssq: "circle.grid.3x3.circle"
        case .dlt: "sparkles"
        }
    }
}
