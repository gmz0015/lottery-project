import SwiftUI
import LotteryKit

enum AppMotion {
    static let quick = Animation.spring(response: 0.22, dampingFraction: 0.82)
    static let page = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let reveal = Animation.spring(response: 0.28, dampingFraction: 0.88)
}

private struct HoverLiftModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    var scale: CGFloat = 1.012
    var yOffset: CGFloat = -1
    var shadowOpacity: Double = 0.12

    func body(content: Content) -> some View {
        content
            .scaleEffect(isEnabled && isHovering ? scale : 1)
            .offset(y: isEnabled && isHovering ? yOffset : 0)
            .shadow(color: .black.opacity(isEnabled && isHovering ? shadowOpacity : 0),
                    radius: isEnabled && isHovering ? 12 : 0,
                    y: isEnabled && isHovering ? 5 : 0)
            .animation(AppMotion.quick, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

private struct InteractiveControlModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isEnabled && isHovering ? 1.035 : 1)
            .brightness(isEnabled && isHovering ? 0.035 : 0)
            .shadow(color: .accentColor.opacity(isEnabled && isHovering ? 0.18 : 0),
                    radius: isEnabled && isHovering ? 10 : 0,
                    y: isEnabled && isHovering ? 3 : 0)
            .animation(AppMotion.quick, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

private struct SoftRowModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(isHovering ? 0.055 : 0))
            }
            .animation(AppMotion.quick, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.012, yOffset: CGFloat = -1, shadowOpacity: Double = 0.12) -> some View {
        modifier(HoverLiftModifier(scale: scale, yOffset: yOffset, shadowOpacity: shadowOpacity))
    }

    func interactiveControl() -> some View {
        modifier(InteractiveControlModifier())
    }

    func softHoverRow() -> some View {
        modifier(SoftRowModifier())
    }

    func softRevealTransition() -> some View {
        transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.985)))
    }
}

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

struct ContentBar<Actions: View>: View {
    let title: String
    var detail: String?
    var systemImage: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)

            if let detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }

            Spacer(minLength: 16)

            actions()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

struct GlassPanel<Content: View>: View {
    var spacing: CGFloat = 14
    var interactive: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .hoverLift(scale: interactive ? 1.006 : 1, yOffset: interactive ? -1 : 0, shadowOpacity: interactive ? 0.08 : 0)
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
        .hoverLift(scale: 1.018, yOffset: -2, shadowOpacity: 0.14)
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
                .id(text)
                .softRevealTransition()
        }
    }
}

struct EmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "tray"

    var body: some View {
        GlassPanel(spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
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
