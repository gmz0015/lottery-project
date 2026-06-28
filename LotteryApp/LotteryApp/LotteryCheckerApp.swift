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
                        Label(item.rawValue, systemImage: item.icon)
                            .tag(item)
                            .accessibilityIdentifier(item.accessibilityID)
                    }
                    .listStyle(.sidebar)
                }
                .navigationSplitViewColumnWidth(200)
            } detail: {
                NavigationStack {
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
            }
            .environment(model)
            .frame(minWidth: 900, minHeight: 600)
        }
    }
}
