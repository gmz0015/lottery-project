import SwiftUI
import Observation

enum AppToastStyle {
    case success
    case info
    case error

    static func inferred(from message: String) -> AppToastStyle {
        if message.hasPrefix("错误") || message.hasPrefix("该期") || message.contains("失败") {
            return .error
        }
        if message.hasPrefix("已") || message.hasPrefix("中奖") {
            return .success
        }
        return .info
    }

    var systemImage: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: .green
        case .info: .accentColor
        case .error: .red
        }
    }
}

struct AppToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: AppToastStyle
}

@MainActor
@Observable
final class AppOverlayCenter {
    var toast: AppToast?
    var loadingMessage: String?

    @ObservationIgnored
    private var dismissTask: Task<Void, Never>?

    func showToast(_ message: String, style: AppToastStyle? = nil, duration: UInt64 = 3_200_000_000) {
        guard !message.isEmpty else { return }

        dismissTask?.cancel()
        let toast = AppToast(message: message, style: style ?? AppToastStyle.inferred(from: message))
        withAnimation(AppMotion.reveal) {
            self.toast = toast
        }

        dismissTask = Task { [weak self, id = toast.id] in
            try? await Task.sleep(nanoseconds: duration)
            await MainActor.run {
                guard self?.toast?.id == id else { return }
                withAnimation(AppMotion.reveal) {
                    self?.toast = nil
                }
            }
        }
    }

    func showLoading(_ message: String) {
        withAnimation(AppMotion.reveal) {
            loadingMessage = message
        }
    }

    func hideLoading() {
        withAnimation(AppMotion.reveal) {
            loadingMessage = nil
        }
    }

    func clearToast() {
        dismissTask?.cancel()
        withAnimation(AppMotion.reveal) {
            toast = nil
        }
    }
}

struct AppOverlayPresenter: ViewModifier {
    let center: AppOverlayCenter

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: .top) {
                    if let loadingMessage = center.loadingMessage {
                        AppLoadingOverlay(message: loadingMessage)
                            .transition(.opacity)
                    }

                    if let toast = center.toast {
                        AppToastView(toast: toast) {
                            center.clearToast()
                        }
                        .padding(.top, 18)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98)))
                        .zIndex(1)
                    }
                }
            }
    }
}

extension View {
    func appOverlayPresenter(_ center: AppOverlayCenter) -> some View {
        modifier(AppOverlayPresenter(center: center))
    }
}

private struct AppToastView: View {
    let toast: AppToast
    let close: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.style.systemImage)
                .foregroundStyle(toast.style.tint)

            Text(toast.message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("关闭")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: 560)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityIdentifier("globalToast")
    }
}

private struct AppLoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 22, y: 10)
        }
        .accessibilityIdentifier("globalLoadingOverlay")
    }
}
