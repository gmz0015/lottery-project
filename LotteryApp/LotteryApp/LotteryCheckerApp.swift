import SwiftUI
import LotteryKit

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "首页"
    case verify = "验奖"
    case tickets = "彩票列表"
    case results = "验奖结果总览"
    case stats = "统计"
    case settings = "设置"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .verify: return "doc.viewfinder"
        case .tickets: return "list.bullet.rectangle"
        case .results: return "checkmark.seal"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
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
                List(SidebarItem.allCases, selection: $selection) { item in
                    Label(item.rawValue, systemImage: item.icon).tag(item)
                }
                .navigationSplitViewColumnWidth(200)
            } detail: {
                NavigationStack {
                    switch selection ?? .dashboard {
                    case .dashboard: DashboardView()
                    case .verify: VerifyView()
                    case .tickets: TicketListView()
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
