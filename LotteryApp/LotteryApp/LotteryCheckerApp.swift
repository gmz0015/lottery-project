import SwiftUI
import LotteryKit

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "首页"
    case verify = "验奖"
    case tickets = "彩票列表"
    case draws = "开奖信息"
    case results = "验奖结果总览"
    case stats = "统计"
    case settings = "设置"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .verify: return "doc.viewfinder"
        case .tickets: return "list.bullet.rectangle"
        case .draws: return "number.square"
        case .results: return "checkmark.seal"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
    var accessibilityID: String {
        switch self {
        case .dashboard: return "sidebar_dashboard"
        case .verify: return "sidebar_verify"
        case .tickets: return "sidebar_tickets"
        case .draws: return "sidebar_draws"
        case .results: return "sidebar_results"
        case .stats: return "sidebar_stats"
        case .settings: return "sidebar_settings"
        }
    }
}

@main
struct LotteryCheckerApp: App {
    @State private var model = AppModel()
    @State private var selection: SidebarItem? = .dashboard
    @AppStorage(AppSettings.Keys.language) private var languageRawValue = LanguagePreference.system.rawValue
    @AppStorage(AppSettings.Keys.timeZoneIdentifier) private var timeZoneIdentifier = ""
    @AppStorage(AppSettings.Keys.appearance) private var appearanceRawValue = AppearancePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .accessibilityLabel("App Logo")

                        Text("彩票验奖")
                            .font(.headline)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    Divider()

                    List(SidebarItem.allCases, selection: $selection) { item in
                        SidebarItemRow(item: item)
                            .tag(item)
                            .accessibilityIdentifier(item.accessibilityID)
                    }
                    .listStyle(.sidebar)
                }
                .navigationSplitViewColumnWidth(200)
            } detail: {
                NavigationStack {
                    ZStack {
                        switch selection ?? .dashboard {
                        case .dashboard: DashboardView()
                        case .verify: VerifyView()
                        case .tickets: TicketListView()
                        case .draws: DrawsView()
                        case .results: ResultsOverviewView()
                        case .stats: StatsView()
                        case .settings: SettingsView()
                        }
                    }
                    .id(selection ?? .dashboard)
                    .transition(.opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.992)))
                }
            }
            .animation(AppMotion.page, value: selection)
            .environment(model)
            .environment(\.locale, selectedLanguage.locale)
            .environment(\.timeZone, selectedTimeZone)
            .preferredColorScheme(selectedAppearance.colorScheme)
            .frame(minWidth: 900, minHeight: 600)
        }
    }

    private var selectedLanguage: LanguagePreference {
        LanguagePreference(rawValue: languageRawValue) ?? .system
    }

    private var selectedTimeZone: TimeZone {
        guard !timeZoneIdentifier.isEmpty, let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return .autoupdatingCurrent
        }
        return timeZone
    }

    private var selectedAppearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRawValue) ?? .system
    }
}

private struct SidebarItemRow: View {
    let item: SidebarItem
    @State private var isHovering = false

    var body: some View {
        Label {
            Text(item.rawValue)
                .lineLimit(1)
        } icon: {
            Image(systemName: item.icon)
                .symbolEffect(.bounce, value: isHovering)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
